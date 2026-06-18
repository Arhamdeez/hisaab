import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_decorations.dart';
import '../core/theme/app_spacing.dart';
import '../core/utils/formatters.dart';
import '../models/transaction.dart';
import '../providers/category_catalog.dart';
import 'empty_state_view.dart';
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const AppAccentBar(),
          const SizedBox(width: 10),
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
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            AppActionChip(label: actionLabel!, onTap: onAction!),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HomeSectionLabel(title: 'Latest activity'),
          GlassContainer(
            radius: AppRadius.lg,
            blur: 10,
            tint: AppColors.glassFillStrong,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            child: const EmptyStateView(
              compact: true,
              icon: Icons.receipt_long_outlined,
              title: 'No transactions this month yet',
              subtitle: 'Confirm a payment or add one manually',
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
          blur: 10,
          tint: AppColors.glassFillStrong,
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
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
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
    final category =
        context.watch<CategoryCatalog>().resolve(transaction.categoryId);
    final color = category.color;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: AppDecorations.iconBadge(color),
            child: Icon(category.icon, color: color, size: 18),
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
                  category.label,
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
                  color: isDebit ? AppColors.expense : AppColors.income,
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
