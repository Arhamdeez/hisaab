import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/utils/formatters.dart';
import '../models/category_info.dart';
import '../models/transaction.dart';
import '../providers/category_catalog.dart';
import '../providers/transaction_provider.dart';
import '../widgets/category_breakdown.dart';
import '../widgets/category_selector.dart';
import '../widgets/glass_container.dart';

class TransactionDetailScreen extends StatefulWidget {
  const TransactionDetailScreen({super.key, required this.transaction});

  final Transaction transaction;

  static Future<void> open(BuildContext context, Transaction transaction) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TransactionDetailScreen(transaction: transaction),
      ),
    );
  }

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late String _categoryId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.transaction.categoryId;
  }

  CategoryInfo _category(BuildContext context) {
    return context.watch<CategoryCatalog>().resolve(_categoryId);
  }

  Future<void> _pickCategory() async {
    if (_saving) return;

    final picked = await showCategoryPickerSheet(
      context,
      selectedId: _categoryId,
      title: 'Change category',
    );
    if (picked == null || picked == _categoryId || !mounted) return;

    setState(() => _saving = true);
    HapticFeedback.lightImpact();

    await context.read<TransactionProvider>().updateTransactionCategory(
          widget.transaction.id,
          picked,
        );

    if (!mounted) return;

    final label = context.read<CategoryCatalog>().resolve(picked).label;
    setState(() {
      _categoryId = picked;
      _saving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved to $label'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tx = widget.transaction;
    final category = _category(context);
    final isDebit = tx.isDebit;
    final amountColor = isDebit ? AppColors.textPrimary : AppColors.income;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppBackground(),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(8, 4, AppSpacing.pageH, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                          color: AppColors.textSecondary,
                        ),
                        Expanded(
                          child: Text(
                            'Transaction',
                            style: theme.textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageH,
                      8,
                      AppSpacing.pageH,
                      AppSpacing.section,
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: category.color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          child: Icon(
                            category.icon,
                            color: category.color,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          tx.merchant,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 12),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${isDebit ? '−' : '+'}${formatCurrency(tx.amount, showDecimals: true)}',
                            style: theme.textTheme.displayLarge?.copyWith(
                              fontSize: 42,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1.5,
                              color: amountColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isDebit ? 'Expense' : 'Income',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageH,
                      AppSpacing.section,
                      AppSpacing.pageH,
                      0,
                    ),
                    child: GlassCard(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                      child: Column(
                        children: [
                          _DetailRow(
                            label: 'Category',
                            value: _CategoryPickerChip(
                              category: category,
                              saving: _saving,
                              onTap: _pickCategory,
                            ),
                          ),
                          const _DetailDivider(),
                          _DetailRow(
                            label: 'Date',
                            value: Text(
                              _formatFullDate(tx.occurredAt),
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          const _DetailDivider(),
                          _DetailRow(
                            label: 'Time',
                            value: Text(
                              formatTime(tx.occurredAt),
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          const _DetailDivider(),
                          _DetailRow(
                            label: 'Source',
                            value: SourceBadge(source: tx.source),
                          ),
                          if (tx.linkedSources.isNotEmpty) ...[
                            const _DetailDivider(),
                            _DetailRow(
                              label: 'Also seen in',
                              value: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                alignment: WrapAlignment.end,
                                children: [
                                  for (final s in tx.linkedSources)
                                    SourceBadge(source: s),
                                ],
                              ),
                            ),
                          ],
                          if (tx.status != TransactionStatus.confirmed) ...[
                            const _DetailDivider(),
                            _DetailRow(
                              label: 'Status',
                              value: _StatusChip(status: tx.status),
                            ),
                          ],
                          if (tx.confidence < 1.0) ...[
                            const _DetailDivider(),
                            _DetailRow(
                              label: 'Match confidence',
                              value: Text(
                                '${(tx.confidence * 100).toStringAsFixed(0)}%',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: tx.confidence >= 0.8
                                      ? AppColors.accent
                                      : AppColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (tx.rawText != null && tx.rawText!.trim().isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageH,
                        AppSpacing.section,
                        AppSpacing.pageH,
                        AppSpacing.navBottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Original message',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          GlassCard(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              tx.rawText!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.navBottom),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatFullDate(DateTime date) {
    return DateFormat('EEEE, d MMMM yyyy').format(date);
  }
}

class _CategoryPickerChip extends StatelessWidget {
  const _CategoryPickerChip({
    required this.category,
    required this.saving,
    required this.onTap,
  });

  final CategoryInfo category;
  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: saving ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Ink(
          decoration: BoxDecoration(
            color: category.color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: category.color.withValues(alpha: 0.28),
              width: 0.85,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(category.icon, size: 16, color: category.color),
                const SizedBox(width: 6),
                Text(
                  category.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                if (saving)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: category.color,
                    ),
                  )
                else
                  Icon(
                    Icons.unfold_more_rounded,
                    size: 16,
                    color: category.color.withValues(alpha: 0.85),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: value,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailDivider extends StatelessWidget {
  const _DetailDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: AppColors.border);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final TransactionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      TransactionStatus.pendingReview => ('Pending review', AppColors.warning),
      TransactionStatus.confirmed => ('Confirmed', AppColors.accent),
      TransactionStatus.ignored => ('Ignored', AppColors.textMuted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
