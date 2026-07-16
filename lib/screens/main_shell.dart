import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_launch_scope.dart';
import '../core/splash_timing.dart';
import '../core/theme/app_colors.dart';
import '../core/motion.dart';
import '../core/theme/app_spacing.dart' show AppRadius;
import '../core/utils/app_refresh.dart' show appRefreshActive;
import '../core/utils/formatters.dart';
import '../features/notifications/notification_service.dart';
import '../models/transaction.dart';
import '../providers/app_preferences.dart';
import '../providers/category_catalog.dart';
import '../providers/transaction_provider.dart';
import '../widgets/category_selector.dart';
import '../widgets/glass_bottom_nav_bar.dart';
import '../widgets/glass_container.dart';
import '../widgets/performant_tab_view.dart';
import '../widgets/settings_tour_overlay.dart';
import '../widgets/spend_focus_hero.dart' show kHeroIntroDuration;
import '../navigation/shell_scope.dart';
import 'home_screen.dart';
import 'transactions_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _index = 0;
  final List<int> _history = [];
  final _homeScrollController = ScrollController();
  final _netBalanceToggleKey = GlobalKey();
  bool _showHomeTour = false;
  bool _homeTourScheduled = false;
  TransactionProvider? _transactions;

  late final List<SettingsTourStep> _homeTourStepList = [
    SettingsTourStep(
      targetKey: _netBalanceToggleKey,
      title: 'Show net balance',
      body:
          'Tap this to change what the big number shows. It switches from '
          'cash out only to your net for the month — money in minus money '
          'out. Tap again when you want cash out back on top.',
      icon: Icons.compare_arrows_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.requestPermission();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _transactions?.removeListener(_onTransactionsChanged);
    _homeScrollController.dispose();
    super.dispose();
  }

  void _onHeroIntroComplete() {
    // Hero intro is visual polish only — tour timing is driven by splash + delay.
  }

  Duration _homeTourDelay() {
    return kHeroIntroDuration + SplashTiming.postBubbleTourDelay;
  }

  void _maybeStartHomeTour() {
    if (_homeTourScheduled || !mounted || _index != 0) return;
    if (!AppLaunchScope.of(context).splashComplete) return;
    final prefs = context.read<AppPreferences>();
    if (!prefs.trackInwardFlow) return;
    if (prefs.hasSeenHomeTour) return;
    if (!context.read<TransactionProvider>().isLoaded) return;

    _homeTourScheduled = true;
    Future<void>.delayed(_homeTourDelay(), () {
      if (!mounted || _index != 0) return;
      if (!AppLaunchScope.of(context).splashComplete) return;
      if (context.read<AppPreferences>().hasSeenHomeTour) return;
      setState(() => _showHomeTour = true);
    });
  }

  void _onTransactionsChanged() {
    if (_transactions?.isLoaded ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartHomeTour());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tx = context.read<TransactionProvider>();
    if (_transactions != tx) {
      _transactions?.removeListener(_onTransactionsChanged);
      _transactions = tx;
      _transactions!.addListener(_onTransactionsChanged);
    }
    _onTransactionsChanged();
  }

  Future<void> _completeHomeTour() async {
    await context.read<AppPreferences>().markHomeTourSeen();
    if (mounted) setState(() => _showHomeTour = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // Share sheets and system pickers can leave a ghost snackbar shell.
      ScaffoldMessenger.of(context).clearSnackBars();
    }
  }

  void _selectTab(int index) {
    if (index == _index) return;
    HapticFeedback.selectionClick();
    setState(() {
      _history.add(_index);
      _index = index;
    });
    // Transactions tab shares Home's selected month and may be stale after
    // background captures — refresh and land on the current month.
    if (index == 1) {
      unawaited(_revealLatestTransactions());
    }
  }

  void _selectPrimaryTab(int index) {
    _selectTab(index);
  }

  Future<void> _revealLatestTransactions() async {
    final provider = context.read<TransactionProvider>();
    final now = DateTime.now();
    final current = DateTime(now.year, now.month);
    if (provider.selectedMonth.year != current.year ||
        provider.selectedMonth.month != current.month) {
      provider.setSelectedMonth(current);
    }
    await provider.reload();
  }

  void _handleBack() {
    setState(() {
      if (_history.isNotEmpty) {
        _index = _history.removeLast();
      } else if (_index != 0) {
        _index = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Allow the system back to exit only when we're already on Home with no
    // history; otherwise back walks us to the previous tab.
    final canPop = _index == 0 && _history.isEmpty;

    return ShellScope(
      selectTab: _selectTab,
      child: PopScope(
        canPop: canPop,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _handleBack();
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          body: Stack(
            fit: StackFit.expand,
            children: [
              const AppBackground(),
              RepaintBoundary(
                child: PerformantTabView(
                  index: _index,
                  children: [
                    HomeScreen(
                      netBalanceToggleKey: _netBalanceToggleKey,
                      scrollController: _homeScrollController,
                      onHeroIntroComplete: _onHeroIntroComplete,
                    ),
                    const TransactionsScreen(),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ValueListenableBuilder<bool>(
                  valueListenable: appRefreshActive,
                  builder: (context, refreshing, child) {
                    return IgnorePointer(
                      ignoring: refreshing,
                      child: AnimatedOpacity(
                        opacity: refreshing ? 0 : 1,
                        duration: const Duration(milliseconds: 140),
                        curve: Curves.easeOut,
                        child: child,
                      ),
                    );
                  },
                  child: RepaintBoundary(
                    child: GlassBottomNavBar(
                      selectedIndex: _index,
                      onSelected: _selectPrimaryTab,
                      destinations: const [
                        GlassNavDestination(
                          icon: Icons.home_outlined,
                          selectedIcon: Icons.home_rounded,
                          label: 'Home',
                        ),
                        GlassNavDestination(
                          icon: Icons.receipt_long_outlined,
                          selectedIcon: Icons.receipt_long_rounded,
                          label: 'Transactions',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_showHomeTour && _index == 0)
                SettingsTourOverlay(
                  key: const ValueKey('home_tour_overlay'),
                  steps: _homeTourStepList,
                  scrollController: _homeScrollController,
                  scrollToTarget: false,
                  bottomObstruction: GlassBottomNavBar.reservedHeight(context),
                  onComplete: _completeHomeTour,
                ),
            ],
          ),
          floatingActionButton: ValueListenableBuilder<bool>(
            valueListenable: appRefreshActive,
            builder: (context, refreshing, _) => AnimatedSwitcher(
            duration: AppMotion.fast,
            switchInCurve: AppMotion.easeOut,
            switchOutCurve: AppMotion.easeIn,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            child: _index == 1 && !refreshing
                ? Padding(
                    key: const ValueKey('add_fab'),
                    padding: EdgeInsets.only(
                      bottom: GlassBottomNavBar.reservedHeight(context) - 10,
                    ),
                    child: FloatingActionButton.extended(
                      onPressed: () => _showAddSheet(context),
                      elevation: 0,
                      highlightElevation: 0,
                      backgroundColor: AppColors.ui,
                      foregroundColor: AppColors.textOnPrimary,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add'),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('no_fab')),
          ),
          ),
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    final trackInward = context.read<AppPreferences>().trackInwardFlow;
    final catalog = context.read<CategoryCatalog>();
    final merchantCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    var categoryId = SpendingCategory.other.storageKey;
    var type = TransactionType.debit;
    var amountInvalid = false;
    var merchantInvalid = false;
    var shakeTick = 0;

    void pulseInvalidHaptics() {
      HapticFeedback.heavyImpact();
      Future<void>.delayed(const Duration(milliseconds: 70), () {
        HapticFeedback.mediumImpact();
      });
    }

    InputDecoration addFieldDecoration({
      required String labelText,
      String? hintText,
      required bool invalid,
    }) {
      const radius = BorderRadius.all(Radius.circular(AppRadius.md));
      const normal = BorderSide(color: AppColors.glassBorder);
      const error = BorderSide(color: AppColors.expense, width: 1.4);
      final side = invalid ? error : normal;
      return InputDecoration(
        labelText: labelText,
        hintText: hintText,
        labelStyle: TextStyle(
          color: invalid ? AppColors.expense : AppColors.textSecondary,
        ),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: side),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(
            color: invalid ? AppColors.expense : AppColors.ui,
            width: 1.4,
          ),
        ),
        border: OutlineInputBorder(borderRadius: radius, borderSide: side),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              decoration: sheetDecoration(),
              padding: EdgeInsets.fromLTRB(
                24,
                12,
                24,
                24 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SheetHandle(),
                    Text(
                      'Add transaction',
                      style: Theme.of(ctx).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 20),
                    _ShakeFeedback(
                      trigger: shakeTick,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: merchantCtrl,
                            onChanged: (_) {
                              if (merchantInvalid) {
                                setSheetState(() => merchantInvalid = false);
                              }
                            },
                            decoration: addFieldDecoration(
                              labelText: 'Merchant / Description',
                              invalid: merchantInvalid,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: amountCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: false,
                            ),
                            inputFormatters: [PositiveAmountInputFormatter()],
                            onChanged: (_) {
                              if (amountInvalid) {
                                setSheetState(() => amountInvalid = false);
                              }
                            },
                            decoration: addFieldDecoration(
                              labelText: 'Amount (Rs)',
                              hintText: '0',
                              invalid: amountInvalid,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    CategorySelector(
                      compact: true,
                      categories: catalog.all,
                      selectedId: categoryId,
                      onSelected: (v) => setSheetState(() => categoryId = v),
                    ),
                    if (trackInward) ...[
                      const SizedBox(height: 18),
                      Text(
                        'Type',
                        style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 12),
                      CashFlowTypeSelector(
                        selected: type,
                        onChanged: (v) => setSheetState(() => type = v),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () {
                        final merchant = merchantCtrl.text.trim();
                        final nextMerchantInvalid = merchant.isEmpty;
                        final nextAmountInvalid =
                            transactionAmountInputError(amountCtrl.text) !=
                                null;
                        if (nextMerchantInvalid || nextAmountInvalid) {
                          pulseInvalidHaptics();
                          setSheetState(() {
                            merchantInvalid = nextMerchantInvalid;
                            amountInvalid = nextAmountInvalid;
                            shakeTick++;
                          });
                          return;
                        }
                        final amount =
                            parseTransactionAmountInput(amountCtrl.text)!;
                        context
                            .read<TransactionProvider>()
                            .addManualTransaction(
                              amount: amount,
                              merchant: merchant,
                              categoryId: categoryId,
                              type: type,
                            );
                        Navigator.pop(ctx);
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 54),
                        backgroundColor: AppColors.ui,
                        foregroundColor: AppColors.textOnPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Quick horizontal shake + driven by [trigger] increments.
class _ShakeFeedback extends StatefulWidget {
  const _ShakeFeedback({required this.trigger, required this.child});

  final int trigger;
  final Widget child;

  @override
  State<_ShakeFeedback> createState() => _ShakeFeedbackState();
}

class _ShakeFeedbackState extends State<_ShakeFeedback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    _offset = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -12), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12, end: 12), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12, end: -10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant _ShakeFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && widget.trigger > 0) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offset,
      builder: (context, child) => Transform.translate(
        offset: Offset(_offset.value, 0),
        child: child,
      ),
      child: widget.child,
    );
  }
}
