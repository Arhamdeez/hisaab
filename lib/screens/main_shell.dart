import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart' show AppRadius;
import '../features/ingest/ingest_service.dart';
import '../features/notifications/notification_service.dart';
import '../models/transaction.dart';
import '../providers/app_preferences.dart';
import '../providers/transaction_provider.dart';
import '../widgets/category_selector.dart';
import '../widgets/glass_bottom_nav_bar.dart';
import '../widgets/glass_container.dart';
import '../navigation/shell_scope.dart';
import 'home_screen.dart';
import 'inbox_screen.dart';
import 'settings_screen.dart';
import 'transactions_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _index = 0;
  int _primaryTab = 0;
  // Tabs visited before the current one, so the system back button returns to
  // the previous screen (e.g. Inbox -> Home) instead of exiting the app.
  final List<int> _history = [];
  IngestService? _ingestService;
  Timer? _reloadDebounce;

  // Drives the fade-slide transition played each time the active tab changes.
  late final AnimationController _pageAnim;
  // +1 slides the new page in from the right (moving forward), -1 from the left.
  double _direction = 1;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const RepaintBoundary(child: HomeScreen()),
      const RepaintBoundary(child: TransactionsScreen()),
      const RepaintBoundary(child: SettingsScreen()),
      const RepaintBoundary(child: InboxScreen()),
    ];
    _pageAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      value: 1,
    );
    _ingestService = context.read<IngestService>();
    _ingestService!.addListener(_onIngestUpdate);
    WidgetsBinding.instance.addObserver(this);

    // Ask for system-notification permission once the UI is on screen, so the
    // OS dialog reliably appears (it won't while the activity isn't resumed).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.requestPermission();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reloadDebounce?.cancel();
    _pageAnim.dispose();
    _ingestService?.removeListener(_onIngestUpdate);
    super.dispose();
  }

  void _onIngestUpdate() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      context.read<TransactionProvider>().reload();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // Share sheets and system pickers can leave a ghost snackbar shell.
      ScaffoldMessenger.of(context).clearSnackBars();
    }
  }

  /// Replays the fade-slide transition for a switch from [from] to [to].
  void _animateTo(int from, int to) {
    _direction = to >= from ? 1 : -1;
    _pageAnim.forward(from: 0);
  }

  void _selectTab(int index) {
    if (index == _index) return;
    setState(() {
      _animateTo(_index, index);
      _history.add(_index);
      _index = index;
      if (index <= 1) _primaryTab = index;
    });
  }

  void _selectPrimaryTab(int index) {
    _selectTab(index);
  }

  void _handleBack() {
    setState(() {
      if (_history.isNotEmpty) {
        final target = _history.removeLast();
        _animateTo(_index, target);
        _index = target;
      } else if (_index != 0) {
        _animateTo(_index, 0);
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
                child: AnimatedBuilder(
                  animation: _pageAnim,
                  builder: (context, child) {
                    final t = Curves.easeOutCubic.transform(_pageAnim.value);
                    return Opacity(
                      opacity: (0.55 + 0.45 * t).clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset((1 - t) * 14 * _direction, 0),
                        child: child,
                      ),
                    );
                  },
                  child: IndexedStack(index: _index, children: _screens),
                ),
              ),
              // Overlay the bar on top of the gradient so BackdropFilter blurs
              // the real background instead of the scaffold's opaque bottom slot.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: GlassBottomNavBar(
                  selectedIndex: _index <= 1 ? _index : _primaryTab,
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
            ],
          ),
          floatingActionButton: _index == 1
              ? Padding(
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
              : null,
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    final trackInward = context.read<AppPreferences>().trackInwardFlow;
    final merchantCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    var category = SpendingCategory.other;
    var type = TransactionType.debit;

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
                    TextField(
                      controller: merchantCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Merchant / Description',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Amount (Rs)',
                      ),
                    ),
                    const SizedBox(height: 14),
                    CategorySelector(
                      compact: true,
                      selected: category,
                      onSelected: (v) => setSheetState(() => category = v),
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
                        final amount = double.tryParse(amountCtrl.text);
                        if (amount == null || merchantCtrl.text.isEmpty) return;
                        context
                            .read<TransactionProvider>()
                            .addManualTransaction(
                              amount: amount,
                              merchant: merchantCtrl.text,
                              category: category,
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
