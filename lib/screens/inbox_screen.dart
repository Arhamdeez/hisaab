import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../widgets/glass_container.dart';
import '../core/theme/app_spacing.dart' show AppSpacing, AppRadius;
import '../core/utils/app_refresh.dart';
import '../core/utils/formatters.dart';
import '../features/parser/category_guesser.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import '../widgets/category_breakdown.dart';
import '../widgets/category_confirm_sheet.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        final pending = provider.pendingTransactions;

        return SafeArea(
          child: AppRefreshScroll(
            child: ListView(
              physics: refreshScrollPhysics,
              padding: AppSpacing.page,
              children: [
                if (pending.isEmpty)
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.55,
                    child: const _EmptyInbox(),
                  )
                else ...[
                  Text(
                    'Review Inbox',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${pending.length} items captured from SMS, email & notifications',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                        ),
                  ),
                  const SizedBox(height: 20),
                  for (final tx in pending)
                    _ReviewCard(
                      transaction: tx,
                      suggestion: provider.suggestCategory(tx),
                      onConfirm: () => _confirmTransaction(context, provider, tx),
                      onIgnore: () => provider.ignoreTransaction(tx.id),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmTransaction(
    BuildContext context,
    TransactionProvider provider,
    Transaction tx,
  ) async {
    final suggestion = provider.suggestCategory(tx);

    if (await provider.tryAutoConfirmTransaction(tx.id)) {
      return;
    }

    if (!context.mounted) return;

    final category = await showCategoryConfirmSheet(
      context,
      transaction: tx,
      suggestion: suggestion,
    );
    if (category == null || !context.mounted) return;
    await provider.confirmTransaction(tx.id, category: category);
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: AppRadius.borderLg,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                size: 36,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'All caught up!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'New transactions from your connected sources will appear here for review.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.transaction,
    required this.suggestion,
    required this.onConfirm,
    required this.onIgnore,
  });

  final Transaction transaction;
  final CategorySuggestion suggestion;
  final VoidCallback onConfirm;
  final VoidCallback onIgnore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final confidence = transaction.confidence * 100;
    final displayCategory = suggestion.isConfident
        ? suggestion.category
        : transaction.category;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SourceBadge(source: transaction.source),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: confidence >= 80
                      ? AppColors.accent.withValues(alpha: 0.12)
                      : AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: AppRadius.borderXs,
                ),
                child: Text(
                  '${confidence.toStringAsFixed(0)}% match',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: confidence >= 80
                        ? AppColors.accent
                        : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  transaction.merchant,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                transaction.isDebit ? 'Expense' : 'Income',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: transaction.isDebit
                      ? AppColors.textMuted
                      : AppColors.income,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${transaction.isDebit ? '−' : '+'}${formatCurrency(transaction.amount)}',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: transaction.isDebit
                  ? AppColors.textPrimary
                  : AppColors.income,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (transaction.isDebit) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  displayCategory.icon,
                  size: 16,
                  color: displayCategory.color,
                ),
                const SizedBox(width: 6),
                Text(
                  suggestion.isConfident
                      ? suggestion.reasonLabel
                      : 'Suggested · ${displayCategory.label}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
          if (transaction.rawText != null) ...[
            const SizedBox(height: 10),
            Text(
              transaction.rawText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onIgnore,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    minimumSize: const Size(0, 46),
                    side: const BorderSide(color: AppColors.borderLight),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: const Text('Ignore'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onConfirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.ui,
                    foregroundColor: AppColors.textOnPrimary,
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: const Text('Confirm'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
