import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/motion.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_decorations.dart';
import '../core/theme/app_spacing.dart';
import '../core/utils/app_refresh.dart';
import '../core/utils/cash_flow.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/glass_container.dart';
import '../core/utils/formatters.dart';
import '../providers/app_preferences.dart';
import '../providers/category_catalog.dart';
import '../providers/transaction_provider.dart';
import '../screens/transaction_detail_screen.dart';
import '../widgets/transaction_tile.dart';

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
    with SingleTickerProviderStateMixin {
  static const _searchMotion = AppMotion.medium;
  static const _bodyMotion = AppMotion.medium;

  String _query = '';
  String? _filterCategoryId;
  _TxSort _sort = _TxSort.timeDesc;
  final _searchFocus = FocusNode();
  final _searchController = TextEditingController();
  bool _searchFocused = false;

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
    super.dispose();
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
        final resultsKey = ValueKey(
          'tx-${selected.year}-${selected.month}-'
          '${categoryId ?? 'all'}-${_query.trim()}-$_sort-${txs.length}',
        );

        return SafeArea(
          child: AppRefreshScroll(
            orbTopOffset: -8,
            orbMinPull: 44,
            child: CustomScrollView(
              physics: refreshScrollPhysics,
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
                                    Text(
                                      'Transactions',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineLarge
                                          ?.copyWith(
                                            letterSpacing: -0.4,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        final now = DateTime.now();
                                        final current =
                                            DateTime(now.year, now.month);
                                        if (selected.year != current.year ||
                                            selected.month != current.month) {
                                          HapticFeedback.selectionClick();
                                          provider.setSelectedMonth(current);
                                        }
                                      },
                                      child: Text(
                                        formatMonthYear(selected),
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
                  padding: const EdgeInsets.fromLTRB(
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
                                child: Column(
                                  children: [
                                    for (var i = 0; i < txs.length; i++) ...[
                                      TransactionTile(
                                        transaction: txs[i],
                                        showSource: true,
                                        compact: true,
                                        onTap: () =>
                                            TransactionDetailScreen.open(
                                          context,
                                          txs[i],
                                        ),
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
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
