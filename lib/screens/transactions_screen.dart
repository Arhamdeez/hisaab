import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/motion.dart';
import '../core/motion/slide_haptics.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_decorations.dart';
import '../core/theme/app_spacing.dart';
import '../core/utils/app_refresh.dart';
import '../core/utils/cash_flow.dart';
import '../widgets/category_selector.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/glass_container.dart';
import '../core/utils/formatters.dart';
import '../models/transaction.dart';
import '../providers/app_preferences.dart';
import '../providers/category_catalog.dart';
import '../providers/transaction_provider.dart';
import '../screens/transaction_detail_screen.dart';
import '../widgets/transaction_tile.dart';

/// True while the transactions list is in multi-select. Lets the shell hide the Add FAB.
final ValueNotifier<bool> txSelectionActive = ValueNotifier<bool>(false);

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

enum _TxSort {
  timeDesc,
  timeAsc,
  amountDesc,
  amountAsc;

  String get label => switch (this) {
        _TxSort.timeDesc => 'Newest first',
        _TxSort.timeAsc => 'Oldest first',
        _TxSort.amountDesc => 'Amount: High to low',
        _TxSort.amountAsc => 'Amount: Low to high',
      };

  String get shortLabel => switch (this) {
        _TxSort.timeDesc => 'Newest',
        _TxSort.timeAsc => 'Oldest',
        _TxSort.amountDesc => 'High',
        _TxSort.amountAsc => 'Low',
      };

  IconData get icon => switch (this) {
        _TxSort.timeDesc || _TxSort.timeAsc => Icons.schedule_rounded,
        _TxSort.amountDesc || _TxSort.amountAsc => Icons.payments_outlined,
      };
}

class _TransactionsScreenState extends State<TransactionsScreen>
    with TickerProviderStateMixin {
  static const _searchMotion = AppMotion.medium;
  static const _bodyMotion = AppMotion.medium;
  static const _scrubEdgeZone = 96.0;
  static const _scrubScrollMin = 260.0;
  static const _scrubScrollMax = 780.0;

  String _query = '';
  String? _filterCategoryId;
  _TxSort _sort = _TxSort.timeDesc;
  final _searchFocus = FocusNode();
  final _searchController = TextEditingController();
  bool _searchFocused = false;
  final _selectedIds = <String>{};
  final _selectionRevision = ValueNotifier<int>(0);
  final _scrollController = ScrollController();
  final _listKey = GlobalKey();
  bool _scrubbing = false;
  int? _scrubAnchorIndex;
  Set<String> _selectionBeforeScrub = {};
  List<String> _visibleIds = const [];
  Offset? _scrubPointer;
  Ticker? _scrubScrollTicker;
  Duration? _lastScrubTick;

  late final AnimationController _searchCtrl;
  late final Animation<double> _chromeFade;
  late final Animation<double> _chromeSize;
  late final Animation<Offset> _chromeSlide;
  late final Animation<double> _cancelReveal;

  /// Search mode: hide chrome and only show matching transactions.
  bool get _isSearching => _searchFocused || _query.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _searchCtrl = AnimationController(vsync: this, duration: _searchMotion);
    final curve = CurvedAnimation(
      parent: _searchCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _chromeFade = Tween<double>(begin: 1, end: 0).animate(curve);
    _chromeSize = Tween<double>(begin: 1, end: 0).animate(curve);
    _chromeSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.06),
    ).animate(curve);
    _cancelReveal = Tween<double>(begin: 0, end: 1).animate(curve);
    _searchFocus.addListener(_onSearchFocusChanged);
  }

  void _onSearchFocusChanged() {
    final focused = _searchFocus.hasFocus;
    if (_searchFocused == focused) return;
    setState(() => _searchFocused = focused);
    _syncSearchAnimation();
    if (focused) HapticFeedback.selectionClick();
  }

  void _syncSearchAnimation() {
    if (_isSearching) {
      if (_searchCtrl.status != AnimationStatus.forward &&
          _searchCtrl.status != AnimationStatus.completed) {
        _searchCtrl.forward();
      }
    } else if (_searchCtrl.status != AnimationStatus.reverse &&
        _searchCtrl.status != AnimationStatus.dismissed) {
      _searchCtrl.reverse();
    }
  }

  @override
  void dispose() {
    _searchFocus.removeListener(_onSearchFocusChanged);
    _searchFocus.dispose();
    _searchController.dispose();
    _searchCtrl.dispose();
    _scrubScrollTicker?.dispose();
    _selectionRevision.dispose();
    _scrollController.dispose();
    txSelectionActive.value = false;
    super.dispose();
  }

  void _publishSelection() {
    _selectionRevision.value++;
    txSelectionActive.value = _selectedIds.isNotEmpty;
  }

  void _clearSelection() {
    if (_selectedIds.isEmpty && !_scrubbing) return;
    _stopScrubAutoScroll();
    setState(() {
      _selectedIds.clear();
      _scrubbing = false;
      _scrubAnchorIndex = null;
      _scrubPointer = null;
    });
    _publishSelection();
  }

  void _toggleSelection(String id) {
    if (_scrubbing) return;
    HapticFeedback.selectionClick();
    if (!_selectedIds.remove(id)) {
      _selectedIds.add(id);
    }
    _publishSelection();
    if (_selectedIds.isEmpty) setState(() {});
  }

  void _beginScrub(int index, String id) {
    if (_scrollController.hasClients) {
      _scrollController.position.hold(() {});
    }
    _selectionBeforeScrub = Set.of(_selectedIds)..add(id);
    _scrubAnchorIndex = index;
    HapticFeedback.mediumImpact();
    _selectedIds.add(id);
    setState(() => _scrubbing = true);
    _publishSelection();
  }

  void _scrubToIndex(int index) {
    final anchor = _scrubAnchorIndex;
    if (anchor == null || _visibleIds.isEmpty) return;
    final lo = index < anchor ? index : anchor;
    final hi = index > anchor ? index : anchor;
    final range = <String>{};
    for (var i = lo; i <= hi && i < _visibleIds.length; i++) {
      if (i >= 0) range.add(_visibleIds[i]);
    }
    final next = {..._selectionBeforeScrub, ...range};
    if (next.length == _selectedIds.length && next.containsAll(_selectedIds)) {
      return;
    }
    _selectedIds
      ..clear()
      ..addAll(next);
    _publishSelection();
    _scrubSelectHaptic();
  }

  int _lastScrubHapticMs = 0;

  void _scrubSelectHaptic() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastScrubHapticMs < 40) return;
    _lastScrubHapticMs = now;
    SlideHaptics.slideTick();
  }

  void _scrubToPosition(Offset global) {
    if (!_scrubbing) return;
    _scrubPointer = global;
    final index = _tileIndexAt(global);
    if (index != null) _scrubToIndex(index);
    _syncScrubAutoScroll();
  }

  double _scrubEdgeSpeed() {
    final pointer = _scrubPointer;
    if (pointer == null || !mounted) return 0;
    final media = MediaQuery.of(context);
    final top = media.padding.top + 8;
    final bottom = media.size.height - media.padding.bottom - 64;
    if (pointer.dy >= bottom - _scrubEdgeZone) {
      final t =
          ((pointer.dy - (bottom - _scrubEdgeZone)) / _scrubEdgeZone)
              .clamp(0.0, 1.0);
      return _scrubScrollMin +
          (_scrubScrollMax - _scrubScrollMin) * Curves.easeIn.transform(t);
    }
    if (pointer.dy <= top + _scrubEdgeZone) {
      final t =
          ((top + _scrubEdgeZone - pointer.dy) / _scrubEdgeZone).clamp(0.0, 1.0);
      return -(_scrubScrollMin +
          (_scrubScrollMax - _scrubScrollMin) * Curves.easeIn.transform(t));
    }
    return 0;
  }

  void _syncScrubAutoScroll() {
    if (_scrubEdgeSpeed() == 0) {
      _stopScrubAutoScroll();
      return;
    }
    _scrubScrollTicker ??= createTicker(_onScrubScrollTick);
    if (!_scrubScrollTicker!.isActive) {
      _lastScrubTick = null;
      _scrubScrollTicker!.start();
    }
  }

  void _onScrubScrollTick(Duration elapsed) {
    if (!mounted || !_scrubbing) {
      _stopScrubAutoScroll();
      return;
    }
    final last = _lastScrubTick ?? elapsed;
    _lastScrubTick = elapsed;
    final dt = (elapsed - last).inMicroseconds / 1e6;
    if (dt <= 0 || dt > 0.05) return;

    final speed = _scrubEdgeSpeed();
    if (speed == 0 || !_scrollController.hasClients) {
      _stopScrubAutoScroll();
      return;
    }

    final position = _scrollController.position;
    final next = (position.pixels + speed * dt)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if (next != position.pixels) {
      _scrollController.jumpTo(next);
    }

    final pointer = _scrubPointer;
    if (pointer != null) {
      final index = _tileIndexAt(pointer);
      if (index != null) _scrubToIndex(index);
    }

    if (next == position.minScrollExtent || next == position.maxScrollExtent) {
      if (speed < 0 && next == position.minScrollExtent) {
        _stopScrubAutoScroll();
      } else if (speed > 0 && next == position.maxScrollExtent) {
        _stopScrubAutoScroll();
      }
    }
  }

  void _stopScrubAutoScroll() {
    _scrubScrollTicker?.stop();
    _lastScrubTick = null;
  }

  int? _tileIndexAt(Offset global) {
    final listenerBox = _listKey.currentContext?.findRenderObject();
    if (listenerBox is! RenderBox) return null;
    RenderBox? flexBox = listenerBox;
    if (listenerBox is RenderProxyBox) {
      flexBox = listenerBox.child;
    }
    if (flexBox is! RenderFlex) return null;

    var tileIndex = 0;
    var bestIndex = 0;
    var bestDist = double.infinity;
    var found = false;
    var child = flexBox.firstChild;
    while (child != null) {
      final parentData = child.parentData! as FlexParentData;
      final next = parentData.nextSibling;
      if (child.size.height > 8) {
        final top = child.localToGlobal(Offset.zero).dy;
        final mid = top + child.size.height / 2;
        final dist = (global.dy - mid).abs();
        if (dist < bestDist) {
          bestDist = dist;
          bestIndex = tileIndex;
          found = true;
        }
        tileIndex++;
      }
      child = next;
    }
    return found ? bestIndex : null;
  }

  void _endScrub() {
    if (!_scrubbing) return;
    _stopScrubAutoScroll();
    setState(() {
      _scrubbing = false;
      _scrubAnchorIndex = null;
      _scrubPointer = null;
    });
  }

  void _showAddedResult(List<Transaction> selected) {
    if (selected.isEmpty) return;
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.backgroundElevated,
      barrierColor: AppColors.shadow.withValues(alpha: 0.72),
      builder: (ctx) => _SelectedTotalSheet(transactions: selected),
    );
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _syncSearchAnimation();
  }

  void _exitSearch() {
    HapticFeedback.lightImpact();
    _searchController.clear();
    _query = '';
    _searchFocus.unfocus();
    setState(() => _searchFocused = false);
    _searchCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<TransactionProvider, AppPreferences, CategoryCatalog>(
      builder: (context, provider, prefs, catalog, _) {
        final selected = provider.selectedMonth;
        final searching = _isSearching;
        final hasQuery = _query.trim().isNotEmpty;
        final categoryId = searching ? null : _filterCategoryId;

        final now = DateTime.now();
        final isCurrentMonth =
            selected.year == now.year && selected.month == now.month;
        final daysInMonth = DateTime(selected.year, selected.month + 1, 0).day;
        final daysSoFar = isCurrentMonth ? now.day : daysInMonth;

        double scopedCashOut(DateTime month) {
          if (categoryId == null) {
            return provider.summaryForMonth(month).totalDebit;
          }
          return CashFlowMetrics.fromTransactions(
            provider
                .historyForMonth(month)
                .where((t) => t.categoryId == categoryId),
          ).cashOut;
        }

        double scopedCashIn(DateTime month) {
          if (categoryId == null) {
            return provider.summaryForMonth(month).totalCredit;
          }
          return CashFlowMetrics.fromTransactions(
            provider
                .historyForMonth(month)
                .where((t) => t.categoryId == categoryId),
          ).cashIn;
        }

        final spent = scopedCashOut(selected);
        final received = scopedCashIn(selected);
        final dailyAvg = spent / (daysSoFar == 0 ? 1 : daysSoFar);

        var monthlySum = 0.0;
        var monthsWithSpend = 0;
        for (var i = 0; i < 6; i++) {
          final m = DateTime(selected.year, selected.month - i);
          final out = scopedCashOut(m);
          if (out > 0) {
            monthlySum += out;
            monthsWithSpend++;
          }
        }
        final monthlyAvg =
            monthsWithSpend == 0 ? 0.0 : monthlySum / monthsWithSpend;

        var txs = provider.historyForMonth(selected);

        if (hasQuery) {
          final q = _query.trim().toLowerCase();
          txs = txs
              .where(
                (t) =>
                    t.merchant.toLowerCase().contains(q) ||
                    catalog
                        .resolve(t.categoryId)
                        .label
                        .toLowerCase()
                        .contains(q),
              )
              .toList();
        }
        if (categoryId != null) {
          txs = txs.where((t) => t.categoryId == categoryId).toList();
        }

        txs = [...txs];
        switch (_sort) {
          case _TxSort.timeDesc:
            txs.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
          case _TxSort.timeAsc:
            txs.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
          case _TxSort.amountDesc:
            txs.sort((a, b) => b.amount.compareTo(a.amount));
          case _TxSort.amountAsc:
            txs.sort((a, b) => a.amount.compareTo(b.amount));
        }

        final hasFilters = hasQuery || categoryId != null;
        final selecting = _selectedIds.isNotEmpty;
        _visibleIds = [for (final t in txs) t.id];
        final resultsKey = ValueKey(
          'tx-${selected.year}-${selected.month}-'
          '${categoryId ?? 'all'}-${_query.trim()}-$_sort-${txs.length}',
        );

        return PopScope(
          canPop: !selecting,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            _clearSelection();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              SafeArea(
                child: AppRefreshScroll(
            orbTopOffset: -8,
            orbMinPull: 44,
            child: CustomScrollView(
              controller: _scrollController,
              physics: _scrubbing
                  ? const NeverScrollableScrollPhysics()
                  : refreshScrollPhysics,
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverToBoxAdapter(
                  child: SizeTransition(
                    sizeFactor: _chromeSize,
                    alignment: AlignmentDirectional(-1, -1),
                    child: FadeTransition(
                      opacity: _chromeFade,
                      child: SlideTransition(
                        position: _chromeSlide,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.pageH,
                            16,
                            AppSpacing.pageH,
                            0,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const AppAccentBar(height: 28),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AnimatedSwitcher(
                                      duration: AppMotion.fast,
                                      child: selecting
                                          ? ValueListenableBuilder<int>(
                                              key: const ValueKey(true),
                                              valueListenable:
                                                  _selectionRevision,
                                              builder: (context, _, _) {
                                                return Text(
                                                  '${_selectedIds.length} selected',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .headlineLarge
                                                      ?.copyWith(
                                                        letterSpacing: -0.4,
                                                      ),
                                                );
                                              },
                                            )
                                          : Text(
                                              'Transactions',
                                              key: const ValueKey(false),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headlineLarge
                                                  ?.copyWith(
                                                    letterSpacing: -0.4,
                                                  ),
                                            ),
                                    ),
                                    const SizedBox(height: 2),
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: selecting
                                          ? null
                                          : () {
                                              final now = DateTime.now();
                                              final current =
                                                  DateTime(now.year, now.month);
                                              if (selected.year !=
                                                      current.year ||
                                                  selected.month !=
                                                      current.month) {
                                                HapticFeedback.selectionClick();
                                                _clearSelection();
                                                provider
                                                    .setSelectedMonth(current);
                                              }
                                            },
                                      child: Text(
                                        selecting
                                            ? 'Tap to select more'
                                            : formatMonthYear(selected),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.textMuted,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (selecting)
                                IconButton(
                                  tooltip: 'Cancel',
                                  onPressed: _clearSelection,
                                  icon: const Icon(Icons.close_rounded),
                                )
                              else
                                _SortButton(
                                  sort: _sort,
                                  onChanged: (s) => setState(() => _sort = s),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: AnimatedBuilder(
                    animation: _searchCtrl,
                    builder: (context, _) {
                      final t =
                          Curves.easeOutCubic.transform(_searchCtrl.value);
                      return Padding(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.pageH,
                          16 - (4 * t),
                          AppSpacing.pageH,
                          0,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocus,
                                onChanged: _onQueryChanged,
                                textInputAction: TextInputAction.search,
                                decoration: InputDecoration(
                                  hintText: 'Search merchant or category',
                                  prefixIcon:
                                      const Icon(Icons.search_rounded),
                                  suffixIcon: searching
                                      ? IconButton(
                                          tooltip:
                                              hasQuery ? 'Clear' : 'Close',
                                          onPressed: !hasQuery
                                              ? _exitSearch
                                              : () {
                                                  _searchController.clear();
                                                  _onQueryChanged('');
                                                },
                                          icon: AnimatedSwitcher(
                                            duration: AppMotion.fast,
                                            child: Icon(
                                              hasQuery
                                                  ? Icons.clear_rounded
                                                  : Icons.close_rounded,
                                              key: ValueKey(hasQuery),
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            ClipRect(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                widthFactor:
                                    _cancelReveal.value.clamp(0.0, 1.0),
                                child: Opacity(
                                  opacity:
                                      _cancelReveal.value.clamp(0.0, 1.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(width: 4),
                                      TextButton(
                                        onPressed: _exitSearch,
                                        child: const Text('Cancel'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizeTransition(
                    sizeFactor: _chromeSize,
                    alignment: AlignmentDirectional(-1, -1),
                    child: FadeTransition(
                      opacity: _chromeFade,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: SizedBox(
                          // Tall enough for chip + selected glow (blur/offset).
                          height: 60,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            clipBehavior: Clip.none,
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.pageH,
                              10,
                              AppSpacing.pageH,
                              10,
                            ),
                            children: [
                              _FilterChip(
                                label: 'All',
                                selected: _filterCategoryId == null,
                                onTap: () => setState(
                                  () => _filterCategoryId = null,
                                ),
                              ),
                              ...catalog.all.map(
                                (c) => _FilterChip(
                                  label: c.label,
                                  selected: _filterCategoryId == c.id,
                                  color: c.color,
                                  onTap: () => setState(
                                    () => _filterCategoryId = c.id,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.pageH,
                    12,
                    AppSpacing.pageH,
                    AppSpacing.navBottom,
                  ),
                  sliver: _SoftFadeResults(
                    animation: _bodyMotion,
                    resultsKey: resultsKey,
                    child: txs.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 48),
                            child: EmptyStateView(
                              icon: searching
                                  ? Icons.search_off_rounded
                                  : Icons.receipt_long_rounded,
                              title: searching && !hasQuery
                                  ? 'Search transactions'
                                  : hasFilters
                                      ? 'No transactions found'
                                      : 'No transactions yet',
                              subtitle: searching && !hasQuery
                                  ? 'Type a merchant or category'
                                  : hasFilters
                                      ? 'Try a different search or category filter'
                                      : 'Confirmed payments for this month will appear here',
                            ),
                          )
                        : Column(
                            children: [
                              SizeTransition(
                                sizeFactor: _chromeSize,
                                alignment: AlignmentDirectional(-1, -1),
                                child: FadeTransition(
                                  opacity: _chromeFade,
                                  child: Column(
                                    children: [
                                      AnimatedSwitcher(
                                        duration: _bodyMotion,
                                        switchInCurve: Curves.easeOutCubic,
                                        switchOutCurve: Curves.easeInCubic,
                                        child: prefs.trackInwardFlow
                                            ? _CashFlowSummary(
                                                key: ValueKey(
                                                  'flow-${categoryId ?? 'all'}',
                                                ),
                                                spent: spent,
                                                received: received,
                                              )
                                            : spent > 0
                                                ? _AveragesCard(
                                                    key: ValueKey(
                                                      'avg-${categoryId ?? 'all'}',
                                                    ),
                                                    dailyAvg: dailyAvg,
                                                    monthlyAvg: monthlyAvg,
                                                  )
                                                : const SizedBox.shrink(
                                                    key: ValueKey('none'),
                                                  ),
                                      ),
                                      if (prefs.trackInwardFlow || spent > 0)
                                        const SizedBox(height: 12),
                                    ],
                                  ),
                                ),
                              ),
                              GlassCard(
                                child: Listener(
                                  key: _listKey,
                                  behavior: HitTestBehavior.translucent,
                                  onPointerMove: (e) =>
                                      _scrubToPosition(e.position),
                                  onPointerUp: (_) => _endScrub(),
                                  onPointerCancel: (_) => _endScrub(),
                                  child: Column(
                                    children: [
                                      for (var i = 0; i < txs.length; i++) ...[
                                        _SelectAwareTile(
                                          id: txs[i].id,
                                          revision: _selectionRevision,
                                          isSelected: _selectedIds.contains,
                                          builder: (selected) {
                                            return TransactionTile(
                                              transaction: txs[i],
                                              showSource: true,
                                              compact: true,
                                              selecting:
                                                  selecting || _scrubbing,
                                              selected: selected,
                                              onTap: () {
                                                if (selecting) {
                                                  _toggleSelection(txs[i].id);
                                                  return;
                                                }
                                                TransactionDetailScreen.open(
                                                  context,
                                                  txs[i],
                                                );
                                              },
                                              onLongPress: () => _beginScrub(
                                                i,
                                                txs[i].id,
                                              ),
                                            );
                                          },
                                        ),
                                        if (i < txs.length - 1)
                                          const Divider(
                                            height: 1,
                                            indent: 72,
                                            endIndent: 16,
                                            color: AppColors.border,
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
              ),
              if (selecting)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ValueListenableBuilder<int>(
                    valueListenable: _selectionRevision,
                    builder: (context, _, _) {
                      return _SelectionActionBar(
                        count: _selectedIds.length,
                        onCancel: _clearSelection,
                        onAdd: () {
                          final selected = [
                            for (final t in txs)
                              if (_selectedIds.contains(t.id)) t,
                          ];
                          _showAddedResult(selected);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SelectAwareTile extends StatefulWidget {
  const _SelectAwareTile({
    required this.id,
    required this.revision,
    required this.isSelected,
    required this.builder,
  });

  final String id;
  final ValueNotifier<int> revision;
  final bool Function(String id) isSelected;
  final Widget Function(bool selected) builder;

  @override
  State<_SelectAwareTile> createState() => _SelectAwareTileState();
}

class _SelectAwareTileState extends State<_SelectAwareTile> {
  late bool _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.isSelected(widget.id);
    widget.revision.addListener(_onRevision);
  }

  @override
  void didUpdateWidget(_SelectAwareTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) {
      oldWidget.revision.removeListener(_onRevision);
      widget.revision.addListener(_onRevision);
    }
    final next = widget.isSelected(widget.id);
    if (next != _selected) _selected = next;
  }

  @override
  void dispose() {
    widget.revision.removeListener(_onRevision);
    super.dispose();
  }

  void _onRevision() {
    final next = widget.isSelected(widget.id);
    if (next == _selected || !mounted) return;
    setState(() => _selected = next);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(child: widget.builder(_selected));
  }
}

class _SelectionActionBar extends StatelessWidget {
  const _SelectionActionBar({
    required this.count,
    required this.onCancel,
    required this.onAdd,
  });

  final int count;
  final VoidCallback onCancel;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          0,
          18,
          bottomInset > 0 ? bottomInset + 8 : 18,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppRadius.borderXxl,
            color: AppColors.backgroundElevated,
            border: Border.all(color: AppColors.glassBorder, width: 0.9),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withValues(alpha: 0.7),
                blurRadius: 28,
                offset: const Offset(0, 14),
                spreadRadius: -4,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: AppRadius.borderXxl,
            child: ColoredBox(
              color: AppColors.backgroundElevated,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Row(
                  children: [
                    Material(
                      color: AppColors.surfaceHigh,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onCancel,
                        child: const SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(Icons.close_rounded, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            count == 1 ? '1 selected' : '$count selected',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Add to total',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: count == 0 ? null : onAdd,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.borderLg,
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('Add'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedTotalSheet extends StatelessWidget {
  const _SelectedTotalSheet({required this.transactions});

  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flow = CashFlowMetrics.fromTransactions(transactions);
    final n = transactions.length;
    final hasIn = flow.cashIn > 0;
    final hasOut = flow.cashOut > 0;
    final primary = hasIn && hasOut
        ? flow.net
        : hasIn
            ? flow.cashIn
            : flow.cashOut;
    final primaryIsIncome = hasIn && (!hasOut || flow.net >= 0);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.xl),
      ),
      child: ColoredBox(
        color: AppColors.backgroundElevated,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(),
              Text('Added', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                n == 1
                    ? 'for 1 selected transaction'
                    : 'for $n selected transactions',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 20),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.glassBorder, width: 0.85),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 16,
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${primaryIsIncome ? '+' : '−'}${formatCurrency(primary.abs())}',
                        style: theme.textTheme.displayLarge?.copyWith(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: primaryIsIncome
                              ? AppColors.income
                              : AppColors.expense,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hasIn && hasOut
                            ? 'Net of selected'
                            : hasIn
                                ? 'Cash in'
                                : 'Cash out',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (hasIn && hasOut) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _SheetStat(
                                label: 'Cash out',
                                value: formatCurrency(flow.cashOut),
                                color: AppColors.expense,
                              ),
                            ),
                            Expanded(
                              child: _SheetStat(
                                label: 'Cash in',
                                value: formatCurrency(flow.cashIn),
                                color: AppColors.income,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (transactions.isNotEmpty) ...[
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.36,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: AppColors.glassBorder,
                        width: 0.85,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        itemCount: transactions.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          color: AppColors.border,
                        ),
                        itemBuilder: (context, i) {
                          final t = transactions[i];
                          final failed = t.isFailed;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    t.merchant,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: failed
                                          ? AppColors.textMuted
                                          : AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  failed
                                      ? 'Failed'
                                      : '${t.isDebit ? '−' : '+'}${formatCurrency(t.amount)}',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: failed
                                        ? AppColors.textMuted
                                        : t.isDebit
                                            ? AppColors.expense
                                            : AppColors.income,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetStat extends StatelessWidget {
  const _SheetStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Soft fade + slight rise when filter / search results change.
class _SoftFadeResults extends StatelessWidget {
  const _SoftFadeResults({
    required this.animation,
    required this.resultsKey,
    required this.child,
  });

  final Duration animation;
  final Key resultsKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: AnimatedSwitcher(
        duration: animation,
        reverseDuration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (current, previous) {
          return Stack(
            alignment: Alignment.topCenter,
            children: [
              ...previous,
              ?current,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(fade);
          return FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: slide,
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: resultsKey,
          child: child,
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.sort, required this.onChanged});

  final _TxSort sort;
  final ValueChanged<_TxSort> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopupMenuButton<_TxSort>(
      initialValue: sort,
      onSelected: onChanged,
      tooltip: 'Sort',
      color: AppColors.backgroundElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.glassBorder),
      ),
      itemBuilder: (context) => _TxSort.values.map((s) {
        final selected = s == sort;
        return PopupMenuItem<_TxSort>(
          value: s,
          child: Row(
            children: [
              Icon(
                s.icon,
                size: 18,
                color: selected ? AppColors.ui : AppColors.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  s.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: selected ? AppColors.ui : AppColors.textPrimary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: AppColors.ui,
                ),
            ],
          ),
        );
      }).toList(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.glassFillStrong,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedRotation(
              turns: _isAscending ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutBack,
              child: const Icon(
                Icons.swap_vert_rounded,
                size: 16,
                color: AppColors.ui,
              ),
            ),
            const SizedBox(width: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    axis: Axis.horizontal,
                    sizeFactor: animation,
                    alignment: AlignmentDirectional(-1, -1),
                    child: child,
                  ),
                );
              },
              child: Text(
                sort.shortLabel,
                key: ValueKey(sort),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _isAscending =>
      sort == _TxSort.timeAsc || sort == _TxSort.amountAsc;
}

class _CashFlowSummary extends StatelessWidget {
  const _CashFlowSummary({
    super.key,
    required this.spent,
    required this.received,
  });

  final double spent;
  final double received;

  @override
  Widget build(BuildContext context) {
    final net = received - spent;
    final theme = Theme.of(context);

    return GlassCard(
      accentGlow: true,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _AvgStat(
                icon: Icons.south_west_rounded,
                label: 'Cash out',
                value: formatCompactCurrency(spent),
              ),
            ),
            const VerticalDivider(
              width: 1,
              thickness: 1,
              indent: 4,
              endIndent: 4,
              color: AppColors.border,
            ),
            Expanded(
              child: _AvgStat(
                icon: Icons.north_east_rounded,
                label: 'Cash in',
                value: formatCompactCurrency(received),
                subtitle: 'Received',
              ),
            ),
            const VerticalDivider(
              width: 1,
              thickness: 1,
              indent: 4,
              endIndent: 4,
              color: AppColors.border,
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.compare_arrows_rounded,
                        size: 14,
                        color: net >= 0 ? AppColors.income : AppColors.expense,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        net >= 0 ? 'Net' : 'Net out',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatCompactCurrency(net.abs()),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: net >= 0 ? AppColors.income : AppColors.expense,
                    ),
                  ),
                  if (received > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${formatPercent((net / received * 100).abs())} of cash in',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AveragesCard extends StatelessWidget {
  const _AveragesCard({
    super.key,
    required this.dailyAvg,
    required this.monthlyAvg,
  });

  final double dailyAvg;
  final double monthlyAvg;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accentGlow: true,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _AvgStat(
                icon: Icons.today_rounded,
                label: 'Daily avg',
                value: formatCompactCurrency(dailyAvg),
              ),
            ),
            const VerticalDivider(
              width: 1,
              thickness: 1,
              indent: 4,
              endIndent: 4,
              color: AppColors.border,
            ),
            Expanded(
              child: _AvgStat(
                icon: Icons.calendar_month_rounded,
                label: 'Monthly avg',
                value: formatCompactCurrency(monthlyAvg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvgStat extends StatelessWidget {
  const _AvgStat({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: AppDecorations.iconBadge(AppColors.ui),
          child: Icon(icon, size: 14, color: AppColors.ui),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.ui;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              gradient: selected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        activeColor.withValues(alpha: 0.32),
                        activeColor.withValues(alpha: 0.1),
                      ],
                    )
                  : null,
              color: selected ? null : AppColors.glassFill,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: selected ? AppColors.ui : AppColors.glassBorder,
                width: 1.5,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
