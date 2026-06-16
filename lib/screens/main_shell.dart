import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart' show AppRadius;
import '../features/ingest/ingest_service.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import '../widgets/glass_bottom_nav_bar.dart';
import '../widgets/glass_container.dart';
import '../navigation/shell_scope.dart';
import 'home_screen.dart';
import 'inbox_screen.dart';
import 'month_end_screen.dart';
import 'settings_screen.dart';
import 'transactions_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  // Tabs visited before the current one, so the system back button returns to
  // the previous screen (e.g. Inbox -> Home) instead of exiting the app.
  final List<int> _history = [];
  IngestService? _ingestService;

  // Bottom bar shows indices 0–2 (Home, Transactions, Report). Settings and
  // Inbox are not bottom-bar tabs — they're reached from the Home header
  // (gear + notification bell).
  static const _screens = [
    HomeScreen(),
    TransactionsScreen(),
    MonthEndScreen(),
    SettingsScreen(),
    InboxScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _ingestService = context.read<IngestService>();
    _ingestService!.addListener(_onIngestUpdate);
  }

  @override
  void dispose() {
    _ingestService?.removeListener(_onIngestUpdate);
    super.dispose();
  }

  void _onIngestUpdate() {
    context.read<TransactionProvider>().reload();
  }

  void _selectTab(int index) {
    if (index == _index) return;
    setState(() {
      _history.add(_index);
      _index = index;
    });
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
              IndexedStack(index: _index, children: _screens),
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
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add'),
                  ),
                )
              : null,
          bottomNavigationBar: GlassBottomNavBar(
            selectedIndex: _index,
            onSelected: _selectTab,
            destinations: [
              const GlassNavDestination(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                label: 'Home',
              ),
              const GlassNavDestination(
                icon: Icons.receipt_long_outlined,
                selectedIcon: Icons.receipt_long_rounded,
                label: 'Transactions',
              ),
              const GlassNavDestination(
                icon: Icons.pie_chart_outline_rounded,
                selectedIcon: Icons.pie_chart_rounded,
                label: 'Report',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    final merchantCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    var category = SpendingCategory.other;
    var type = TransactionType.debit;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.backgroundElevated,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppRadius.xl),
                ),
                border: Border(top: BorderSide(color: AppColors.borderLight)),
              ),
              padding: EdgeInsets.fromLTRB(
                24,
                12,
                24,
                24 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    Text(
                      'Add transaction',
                      textAlign: TextAlign.center,
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
                    const SizedBox(height: 12),
                    DropdownButtonFormField<SpendingCategory>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: SpendingCategory.values
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(c.label),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setSheetState(() => category = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<TransactionType>(
                      segments: const [
                        ButtonSegment(
                          value: TransactionType.debit,
                          label: Text('Expense'),
                          icon: Icon(Icons.arrow_upward_rounded),
                        ),
                        ButtonSegment(
                          value: TransactionType.credit,
                          label: Text('Income'),
                          icon: Icon(Icons.arrow_downward_rounded),
                        ),
                      ],
                      selected: {type},
                      onSelectionChanged: (s) {
                        setSheetState(() => type = s.first);
                      },
                    ),
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
                        backgroundColor: AppColors.primary,
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
