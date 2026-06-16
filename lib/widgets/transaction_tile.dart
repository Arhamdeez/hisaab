import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_decorations.dart';
import '../core/theme/app_spacing.dart';
import '../core/utils/formatters.dart';
import '../models/transaction.dart';

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
                decoration: AppDecorations.iconBadge(transaction.category.color),
                child: Icon(
                  transaction.category.icon,
                  color: transaction.category.color,
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
                      _subtitle(),
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
                  const SizedBox(height: 3),
                  Text(
                    formatShortDate(transaction.occurredAt),
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

  String _subtitle() {
    final base = transaction.category.label;
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
