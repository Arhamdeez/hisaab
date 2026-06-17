import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_decorations.dart';
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

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const MonthEndScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppBackground(),
          Consumer2<TransactionProvider, AppPreferences>(
            builder: (context, provider, prefs, _) {
              final summary = provider.summaryForMonth(provider.selectedMonth);
              final trend = _buildTrend(provider, provider.selectedMonth);
              final income = prefs.resolveIncome(summary);

              return SafeArea(
                child: AppRefreshScroll(
                  child: CustomScrollView(
                    physics: refreshScrollPhysics,
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 0, 0),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.arrow_back_rounded),
                                color: AppColors.textSecondary,
                              ),
                              const AppAccentBar(height: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Month-end report',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(letterSpacing: -0.3),
                                    ),
                                    Text(
                                      formatMonthYear(provider.selectedMonth),
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
                              const SizedBox(width: AppSpacing.pageH),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.pageH,
                            12,
                            AppSpacing.pageH,
                            0,
                          ),
                          child: BalanceHeroCard(
                            totalExpense: summary.totalDebit,
                            totalIncome: income,
                            showIncome: prefs.showIncome,
                            trackInwardFlow: prefs.trackInwardFlow,
                            totalReceived: summary.totalCredit,
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
                  child: _StatGrid(
                    summary: summary,
                    trackInwardFlow: prefs.trackInwardFlow,
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
                  child: CategoryReportSection(
                    summaries: summary.byCategory,
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
                    month: provider.selectedMonth,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageH,
                    24,
                    AppSpacing.pageH,
                    32,
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
          ),
        ],
      ),
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
  const _StatGrid({
    required this.summary,
    required this.trackInwardFlow,
  });

  final MonthlySummary summary;
  final bool trackInwardFlow;

  @override
  Widget build(BuildContext context) {
    if (trackInwardFlow) {
      final net = summary.totalCredit - summary.totalDebit;
      return Row(
        children: [
          Expanded(
            child: _StatCard(
              label: 'Cash in',
              value: formatCurrency(summary.totalCredit),
              icon: Icons.north_east_rounded,
              color: AppColors.income,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              label: net >= 0 ? 'Net cash' : 'Net out',
              value: formatCurrency(net.abs()),
              icon: Icons.compare_arrows_rounded,
              color: net >= 0 ? AppColors.income : AppColors.expense,
            ),
          ),
        ],
      );
    }

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
            color: AppColors.ui,
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
