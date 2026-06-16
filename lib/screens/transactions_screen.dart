import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/utils/app_refresh.dart';
import '../widgets/glass_container.dart';
import '../core/utils/formatters.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import '../widgets/transaction_tile.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _query = '';
  SpendingCategory? _filterCategory;

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
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
                    t.category.label
                        .toLowerCase()
                        .contains(_query.toLowerCase()),
              )
              .toList();
        }
        if (_filterCategory != null) {
          txs = txs.where((t) => t.category == _filterCategory).toList();
        }

        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageH,
                  16,
                  AppSpacing.pageH,
                  0,
                ),
                child: Text(
                  'Transactions',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ),
              Padding(
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
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _filterCategory == null,
                      onTap: () => setState(() => _filterCategory = null),
                    ),
                    ...SpendingCategory.values.map(
                      (c) => _FilterChip(
                        label: c.label,
                        selected: _filterCategory == c,
                        color: c.color,
                        onTap: () => setState(() => _filterCategory = c),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AppRefreshScroll(
                  child: txs.isEmpty
                      ? ListView(
                          physics: refreshScrollPhysics,
                          padding: AppSpacing.page,
                          children: [
                            SizedBox(
                              height: MediaQuery.sizeOf(context).height * 0.25,
                            ),
                            Text(
                              'No transactions found',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.textMuted),
                            ),
                          ],
                        )
                      : ListView(
                          physics: refreshScrollPhysics,
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.pageH,
                            12,
                            AppSpacing.pageH,
                            AppSpacing.navBottom,
                          ),
                          children: [
                            if (summary.totalDebit > 0) ...[
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
        );
      },
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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
    final activeColor = color ?? AppColors.primary;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? activeColor.withValues(alpha: 0.14)
                : AppColors.glassFill,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected
                  ? activeColor.withValues(alpha: 0.55)
                  : AppColors.glassBorder,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? activeColor : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}
