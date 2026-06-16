import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/app_refresh.dart';
import '../core/utils/formatters.dart';
import '../models/transaction.dart';
import '../providers/app_preferences.dart';
import '../providers/transaction_provider.dart';
import '../features/month_end/csv_exporter.dart';
import '../widgets/glass_container.dart';
import '../core/theme/app_spacing.dart' show AppSpacing, AppRadius;
import '../widgets/balance_hero_card.dart';
import '../widgets/cash_flow_chart.dart';
import '../widgets/category_breakdown.dart';

class MonthEndScreen extends StatelessWidget {
  const MonthEndScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<TransactionProvider, AppPreferences>(
      builder: (context, provider, prefs, _) {
        final summary = provider.summaryForMonth(provider.selectedMonth);
        final trend = _buildTrend(provider, provider.selectedMonth);
        final income = prefs.hasMonthlyIncome
            ? prefs.monthlyIncome
            : summary.totalCredit;
        final donutData = summary.byCategory
            .map(
              (s) => (
                label: s.category.label,
                value: s.total,
                color: s.category.color,
              ),
            )
            .toList();

        return SafeArea(
          child: AppRefreshScroll(
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Month-end report',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatMonthYear(provider.selectedMonth),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textMuted,
                            ),
                      ),
                      const SizedBox(height: 20),
                      BalanceHeroCard(
                        totalExpense: summary.totalDebit,
                        totalIncome: income,
                        showIncome: prefs.showIncome,
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageH,
                    24,
                    AppSpacing.pageH,
                    0,
                  ),
                  child: _StatGrid(summary: summary),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageH,
                    24,
                    AppSpacing.pageH,
                    0,
                  ),
                  child: SpendingTrendChart(
                    monthlyTotals: trend.totals,
                    monthLabels: trend.labels,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageH,
                    24,
                    AppSpacing.pageH,
                    0,
                  ),
                  child: GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'By category',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        CategoryDonutChart(
                          summaries: donutData,
                          total: summary.totalDebit,
                        ),
                        const SizedBox(height: 20),
                        CategoryBreakdownList(
                          summaries: summary.byCategory,
                          totalExpense: summary.totalDebit,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageH,
                    24,
                    AppSpacing.pageH,
                    0,
                  ),
                  child: _SourceBreakdown(summary: summary),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageH,
                    24,
                    AppSpacing.pageH,
                    0,
                  ),
                  child: _TopMerchants(summary: summary),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageH,
                    24,
                    AppSpacing.pageH,
                    0,
                  ),
                  child: CashFlowChart(
                    dailySpending: summary.dailySpending,
                    totalExpense: summary.totalDebit,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageH,
                    24,
                    AppSpacing.pageH,
                    AppSpacing.navBottom,
                  ),
                  child: OutlinedButton.icon(
                    onPressed: () => CsvExporter.exportMonth(
                      transactions:
                          provider.transactionsForMonth(provider.selectedMonth),
                      year: summary.year,
                      month: summary.month,
                    ),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Export CSV'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      side: const BorderSide(color: AppColors.borderLight),
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
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

  ({List<double> totals, List<String> labels}) _buildTrend(
    TransactionProvider provider,
    DateTime current,
  ) {
    final totals = <double>[];
    final labels = <String>[];

    for (var i = 4; i >= 0; i--) {
      final m = DateTime(current.year, current.month - i);
      final s = provider.summaryForMonth(m);
      totals.add(s.totalDebit);
      labels.add(formatShortMonth(m));
    }

    return (totals: totals, labels: labels);
  }
}

class _SourceBreakdown extends StatelessWidget {
  const _SourceBreakdown({required this.summary});

  final MonthlySummary summary;

  @override
  Widget build(BuildContext context) {
    if (summary.bySource.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'By source',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          ...summary.bySource.entries.map((e) {
            final label = switch (e.key) {
              TransactionSource.notification => 'App Notifications',
              TransactionSource.sms => 'SMS',
              TransactionSource.gmail => 'Gmail',
              TransactionSource.manual => 'Manual',
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    formatCurrency(e.value),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TopMerchants extends StatelessWidget {
  const _TopMerchants({required this.summary});

  final MonthlySummary summary;

  @override
  Widget build(BuildContext context) {
    if (summary.topMerchants.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top merchants',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          ...summary.topMerchants.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      m.merchant,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    formatCurrency(m.total),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.summary});

  final MonthlySummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Avg / day',
            value: formatCurrency(
              summary.totalDebit /
                  (summary.dailySpending.where((d) => d > 0).length.clamp(1, 31)),
            ),
            icon: Icons.trending_up_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Categories',
            value: '${summary.byCategory.length}',
            icon: Icons.category_rounded,
            color: AppColors.income,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
