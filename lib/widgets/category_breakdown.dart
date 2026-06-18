import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_decorations.dart';
import '../core/theme/app_spacing.dart';
import '../core/utils/formatters.dart';
import '../models/transaction.dart';
import '../providers/category_catalog.dart';
import 'cash_flow_chart.dart';
import 'empty_state_view.dart';
import 'glass_container.dart';

/// Premium category breakdown for the month-end report.
class CategoryReportSection extends StatelessWidget {
  const CategoryReportSection({
    super.key,
    required this.summaries,
    required this.totalExpense,
  });

  final List<CategorySummary> summaries;
  final double totalExpense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catalog = context.watch<CategoryCatalog>();
    final donutData = summaries
        .map(
          (s) => (
            label: catalog.resolve(s.categoryId).label,
            value: s.total,
            color: catalog.resolve(s.categoryId).color,
          ),
        )
        .toList();

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppAccentBar(height: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'By category',
                      style: theme.textTheme.titleLarge,
                    ),
                    if (summaries.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${summaries.length} categories · ${formatCompactCurrency(totalExpense)}',
                        style: theme.textTheme.bodySmall?.copyWith(
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
          const SizedBox(height: 20),
          if (summaries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: EmptyStateView(
                compact: true,
                icon: Icons.pie_chart_outline_rounded,
                title: 'No category data yet',
                subtitle: 'Confirm spending this month to see the breakdown',
              ),
            )
          else ...[
            CategoryDonutChart(
              summaries: donutData,
              total: totalExpense,
            ),
            const SizedBox(height: 8),
            _CategoryLegendStrip(
              summaries: summaries,
              total: totalExpense,
              catalog: catalog,
            ),
            const SizedBox(height: 20),
            GlassContainer(
              radius: AppRadius.lg,
              blur: 8,
              tint: AppColors.glassFill,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < summaries.length; i++) ...[
                    _CategoryReportRow(
                      summary: summaries[i],
                      total: totalExpense,
                      rank: i + 1,
                      isLeader: i == 0,
                      catalog: catalog,
                    ),
                    if (i < summaries.length - 1)
                      const Divider(
                        height: 1,
                        indent: 68,
                        endIndent: 16,
                        color: AppColors.border,
                      ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryLegendStrip extends StatelessWidget {
  const _CategoryLegendStrip({
    required this.summaries,
    required this.total,
    required this.catalog,
  });

  final List<CategorySummary> summaries;
  final double total;
  final CategoryCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final top = summaries.take(4).toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: top.map((s) {
        final info = catalog.resolve(s.categoryId);
        final pct = total > 0 ? s.total / total : 0.0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: info.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: info.color.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: info.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                info.label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(width: 6),
              Text(
                formatPercent(pct * 100),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: info.color,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _CategoryReportRow extends StatelessWidget {
  const _CategoryReportRow({
    required this.summary,
    required this.total,
    required this.rank,
    required this.isLeader,
    required this.catalog,
  });

  final CategorySummary summary;
  final double total;
  final int rank;
  final bool isLeader;
  final CategoryCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = catalog.resolve(summary.categoryId);
    final pct = total > 0 ? summary.total / total : 0.0;
    final color = info.color;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: AppDecorations.iconBadge(color),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(info.icon, color: color, size: 20),
                    if (isLeader)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.ui,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.backgroundElevated,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            info.label,
                            style: theme.textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                color.withValues(alpha: 0.24),
                                color.withValues(alpha: 0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(
                              color: color.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            formatPercent(pct * 100),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${summary.count} payment${summary.count == 1 ? '' : 's'} · #$rank',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                formatCurrency(summary.total),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: SizedBox(
              height: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: AppColors.surfaceHigh),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: pct.clamp(0.0, 1.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color,
                            color.withValues(alpha: 0.55),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 1),
                          ),
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
    );
  }
}

class SourceBadge extends StatelessWidget {
  const SourceBadge({super.key, required this.source});

  final TransactionSource source;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (source) {
      TransactionSource.notification => (
          'Notification',
          Icons.notifications_active_outlined,
          AppColors.ui,
        ),
      TransactionSource.sms => ('SMS', Icons.sms_outlined, AppColors.income),
      TransactionSource.gmail => ('Gmail', Icons.mail_outline, AppColors.warning),
      TransactionSource.manual => ('Manual', Icons.edit_outlined, AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.borderXs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
