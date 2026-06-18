import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/motion.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_decorations.dart';
import '../core/theme/app_spacing.dart';
import '../core/utils/app_refresh.dart';
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

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _query = '';
  String? _filterCategoryId;
  _TxSort _sort = _TxSort.timeDesc;

  @override
  Widget build(BuildContext context) {
    return Consumer3<TransactionProvider, AppPreferences, CategoryCatalog>(
      builder: (context, provider, prefs, catalog, _) {
        final selected = provider.selectedMonth;
        final summary = provider.summaryForMonth(selected);

        // Daily average for the selected month (uses days elapsed for the
        // current month, full days otherwise).
        final now = DateTime.now();
        final isCurrentMonth =
            selected.year == now.year && selected.month == now.month;
        final daysInMonth = DateTime(selected.year, selected.month + 1, 0).day;
        final daysSoFar = isCurrentMonth ? now.day : daysInMonth;
        final dailyAvg = summary.totalDebit / (daysSoFar == 0 ? 1 : daysSoFar);

        // Monthly average across the trailing 6 months that had spending.
        var monthlySum = 0.0;
        var monthsWithSpend = 0;
        for (var i = 0; i < 6; i++) {
          final m = DateTime(selected.year, selected.month - i);
          final s = provider.summaryForMonth(m);
          if (s.totalDebit > 0) {
            monthlySum += s.totalDebit;
            monthsWithSpend++;
          }
        }
        final monthlyAvg =
            monthsWithSpend == 0 ? 0.0 : monthlySum / monthsWithSpend;

        var txs = provider.transactionsForMonth(selected);
        if (_query.isNotEmpty) {
          txs = txs
              .where(
                (t) =>
                    t.merchant.toLowerCase().contains(_query.toLowerCase()) ||
                    catalog
                        .resolve(t.categoryId)
                        .label
                        .toLowerCase()
                        .contains(_query.toLowerCase()),
              )
              .toList();
        }
        if (_filterCategoryId != null) {
          txs = txs.where((t) => t.categoryId == _filterCategoryId).toList();
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

        final hasFilters = _query.isNotEmpty || _filterCategoryId != null;

        return SafeArea(
          child: AppRefreshScroll(
            orbTopOffset: -8,
            orbMinPull: 44,
            child: CustomScrollView(
              physics: refreshScrollPhysics,
              slivers: [
                SliverToBoxAdapter(
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
                              Text(
                                formatMonthYear(selected),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w600,
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
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageH,
                      16,
                      AppSpacing.pageH,
                      0,
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: const InputDecoration(
                        hintText: 'Search merchant or category',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.pageH,
                        ),
                        children: [
                          _FilterChip(
                            label: 'All',
                            selected: _filterCategoryId == null,
                            onTap: () => setState(() => _filterCategoryId = null),
                          ),
                          ...catalog.all.map(
                            (c) => _FilterChip(
                              label: c.label,
                              selected: _filterCategoryId == c.id,
                              color: c.color,
                              onTap: () => setState(() => _filterCategoryId = c.id),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (txs.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: EmptyStateView(
                        icon: Icons.receipt_long_rounded,
                        title: hasFilters
                            ? 'No transactions found'
                            : 'No transactions yet',
                        subtitle: hasFilters
                            ? 'Try a different search or category filter'
                            : 'Confirmed payments for this month will appear here',
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageH,
                      12,
                      AppSpacing.pageH,
                      AppSpacing.navBottom,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        if (prefs.trackInwardFlow) ...[
                          _CashFlowSummary(
                            spent: summary.totalDebit,
                            received: summary.totalCredit,
                          ),
                          const SizedBox(height: 12),
                        ] else if (summary.totalDebit > 0) ...[
                          _AveragesCard(
                            dailyAvg: dailyAvg,
                            monthlyAvg: monthlyAvg,
                          ),
                          const SizedBox(height: 12),
                        ],
                        GlassCard(
                          child: Column(
                            children: [
                              for (var i = 0; i < txs.length; i++) ...[
                                TransactionTile(
                                  transaction: txs[i],
                                  showSource: true,
                                  compact: true,
                                  onTap: () => TransactionDetailScreen.open(
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
                      ]),
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
                    color: selected
                        ? AppColors.ui
                        : AppColors.textPrimary,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
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
            // Flip the arrow for ascending orders so the toggle feels physical.
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
                    axisAlignment: -1,
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
  const _AveragesCard({required this.dailyAvg, required this.monthlyAvg});

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
  });

  final IconData icon;
  final String label;
  final String value;

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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: AppMotion.fast,
                    child: Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: activeColor == AppColors.ui
                          ? AppColors.ui
                          : activeColor,
                    ),
                  ),
                ),
                if (selected) const SizedBox(width: 5),
                Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: selected
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
    );
  }
}
