import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_decorations.dart';
import '../core/theme/app_spacing.dart';
import '../core/utils/formatters.dart';
import '../models/category_info.dart';
import '../models/transaction.dart';
import '../providers/category_catalog.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.onLongPress,
    this.showSource = false,
    this.compact = false,
    this.selected = false,
    this.selecting = false,
  });

  final Transaction transaction;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showSource;
  final bool compact;
  final bool selected;
  final bool selecting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDebit = transaction.isDebit;
    final isFailed = transaction.isFailed;
    final category = context.watch<CategoryCatalog>().resolve(transaction.categoryId);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(compact ? 0 : AppRadius.lg),
        child: Ink(
          decoration: compact
              ? BoxDecoration(
                  color: selected
                      ? AppColors.ui.withValues(alpha: 0.10)
                      : Colors.transparent,
                )
              : AppDecorations.card(),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 16 : 16,
            vertical: compact ? 13 : 14,
          ),
          child: Row(
            children: [
              _LeadingBadge(
                category: category,
                selecting: selecting,
                selected: selected,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.merchant,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _subtitle(category),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isFailed ? 'Failed' : '${isDebit ? '−' : '+'}${formatCurrency(transaction.amount)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isFailed
                          ? AppColors.textMuted
                          : isDebit
                              ? AppColors.expense
                              : AppColors.income,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    softWrap: false,
                  ),
                  if (isFailed && transaction.amount > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      formatCurrency(transaction.amount),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textDim,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    '${formatShortDate(transaction.occurredAt)} · '
                    '${formatTime(transaction.occurredAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle(CategoryInfo category) {
    if (transaction.isFailed) return 'Failed payment';
    final base = category.label;
    if (!showSource) return base;
    return '$base · ${_sourceLabel(transaction.source)}';
  }

  String _sourceLabel(TransactionSource source) => switch (source) {
        TransactionSource.notification => 'App',
        TransactionSource.sms => 'SMS',
        TransactionSource.gmail => 'Email',
        TransactionSource.manual => 'Manual',
      };
}

class _LeadingBadge extends StatelessWidget {
  const _LeadingBadge({
    required this.category,
    required this.selecting,
    required this.selected,
  });

  final CategoryInfo category;
  final bool selecting;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (selecting) {
      return Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          color: selected ? AppColors.ui : AppColors.glassFill,
          border: Border.all(
            color: selected ? AppColors.ui : AppColors.glassBorder,
            width: 1.5,
          ),
        ),
        child: Icon(
          selected ? Icons.check_rounded : Icons.circle_outlined,
          color: selected ? AppColors.textOnPrimary : AppColors.textMuted,
          size: 20,
        ),
      );
    }

    return Container(
      width: 42,
      height: 42,
      decoration: AppDecorations.iconBadge(category.color),
      child: Icon(
        category.icon,
        color: category.color,
        size: 19,
      ),
    );
  }
}
