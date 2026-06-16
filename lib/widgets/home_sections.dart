import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/utils/formatters.dart';
import '../models/transaction.dart';
import 'glass_container.dart';

/// Editorial section label used on Home.
class HomeSectionLabel extends StatelessWidget {
  const HomeSectionLabel({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionLabel!,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class HomeCategoriesCard extends StatelessWidget {
  const HomeCategoriesCard({
    super.key,
    required this.categories,
    required this.totalSpent,
    this.onViewAll,
  });

  final List<CategorySummary> categories;
  final double totalSpent;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    final top = categories.take(4).toList();
    final topTotal = top.fold<double>(0, (sum, c) => sum + c.total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionLabel(
          title: 'Where it went',
          subtitle:
              '${top.length} categories · ${formatCompactCurrency(topTotal)}',
          actionLabel: 'View all',
          onAction: onViewAll,
        ),
        GlassContainer(
          radius: AppRadius.lg,
          enableBlur: false,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < top.length; i++) ...[
                _CategoryLine(
                  summary: top[i],
                  total: totalSpent,
                ),
                if (i < top.length - 1)
                  const Divider(
                    height: 1,
                    indent: 64,
                    endIndent: 16,
                    color: AppColors.border,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryLine extends StatelessWidget {
  const _CategoryLine({
    required this.summary,
    required this.total,
  });

  final CategorySummary summary;
  final double total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = total > 0 ? summary.total / total : 0.0;
    final color = summary.category.color;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(summary.category.icon, color: color, size: 18),
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
                        summary.category.label,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      formatCurrency(summary.total),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 4,
                          backgroundColor: AppColors.surfaceHigh,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      formatPercent(pct * 100),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HomeRecentActivity extends StatelessWidget {
  const HomeRecentActivity({
    super.key,
    required this.transactions,
    this.onViewAll,
  });

  final List<Transaction> transactions;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HomeSectionLabel(title: 'Latest activity'),
          GlassContainer(
            radius: AppRadius.lg,
            enableBlur: false,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: Text(
              'No transactions this month yet',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
          ),
        ],
      );
    }

    final groups = _groupByDay(transactions);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionLabel(
          title: 'Latest activity',
          subtitle: '${transactions.length} recent',
          actionLabel: 'View all',
          onAction: onViewAll,
        ),
        GlassContainer(
          radius: AppRadius.lg,
          enableBlur: false,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var g = 0; g < groups.length; g++) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Text(
                    groups[g].label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.textMuted,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                for (var i = 0; i < groups[g].items.length; i++) ...[
                  _RecentLine(transaction: groups[g].items[i]),
                  if (!_isLastLine(groups, g, i))
                    const Divider(
                      height: 1,
                      indent: 68,
                      endIndent: 16,
                      color: AppColors.border,
                    ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  static List<({String label, List<Transaction> items})> _groupByDay(
    List<Transaction> txs,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final ordered = <String, List<Transaction>>{};
    for (final tx in txs) {
      final day = DateTime(
        tx.occurredAt.year,
        tx.occurredAt.month,
        tx.occurredAt.day,
      );
      final diff = today.difference(day).inDays;
      final label = switch (diff) {
        0 => 'Today',
        1 => 'Yesterday',
        _ => formatShortDate(tx.occurredAt),
      };
      ordered.putIfAbsent(label, () => []).add(tx);
    }

    return ordered.entries
        .map((e) => (label: e.key, items: e.value))
        .toList();
  }

  static bool _isLastLine(
    List<({String label, List<Transaction> items})> groups,
    int groupIndex,
    int itemIndex,
  ) {
    final isLastGroup = groupIndex == groups.length - 1;
    final isLastItem = itemIndex == groups[groupIndex].items.length - 1;
    return isLastGroup && isLastItem;
  }
}

class _RecentLine extends StatelessWidget {
  const _RecentLine({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDebit = transaction.isDebit;
    final color = transaction.category.color;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(transaction.category.icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.merchant,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  transaction.category.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isDebit ? '−' : '+'}${formatCurrency(transaction.amount)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isDebit ? AppColors.textPrimary : AppColors.income,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatTime(transaction.occurredAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textDim,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
