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
    this.showSource = false,
    this.compact = false,
  });

  final Transaction transaction;
  final VoidCallback? onTap;
  final bool showSource;
  final bool compact;

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
        borderRadius: BorderRadius.circular(compact ? 0 : AppRadius.lg),
        child: Ink(
          decoration: compact ? null : AppDecorations.card(),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 16 : 16,
            vertical: compact ? 13 : 14,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: AppDecorations.iconBadge(category.color),
                child: Icon(
                  category.icon,
                  color: category.color,
                  size: 19,
                ),
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
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _subtitle(category),
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
                    isFailed ? 'Failed' : '${isDebit ? '−' : '+'}${formatCurrency(transaction.amount)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isFailed
                          ? AppColors.textMuted
                          : isDebit
                              ? AppColors.expense
                              : AppColors.income,
                      fontWeight: FontWeight.w700,
                    ),
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
