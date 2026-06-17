import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/utils/formatters.dart';
import '../features/parser/category_guesser.dart';
import '../models/transaction.dart';
import 'category_selector.dart';

/// Bottom sheet to pick a spending category when confirming a review item.
Future<SpendingCategory?> showCategoryConfirmSheet(
  BuildContext context, {
  required Transaction transaction,
  required CategorySuggestion suggestion,
}) {
  return showModalBottomSheet<SpendingCategory>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CategoryConfirmSheet(
      transaction: transaction,
      suggestion: suggestion,
    ),
  );
}

class _CategoryConfirmSheet extends StatefulWidget {
  const _CategoryConfirmSheet({
    required this.transaction,
    required this.suggestion,
  });

  final Transaction transaction;
  final CategorySuggestion suggestion;

  @override
  State<_CategoryConfirmSheet> createState() => _CategoryConfirmSheetState();
}

class _CategoryConfirmSheetState extends State<_CategoryConfirmSheet> {
  late SpendingCategory _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.suggestion.category;
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final theme = Theme.of(context);

    return Container(
      decoration: sheetDecoration(),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(),
          Text(
            'Pick a category',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            '${tx.merchant} · ${formatCurrency(tx.amount)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.glassFillStrong,
                  AppColors.glassFill,
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: widget.suggestion.isConfident
                      ? AppColors.ui
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.suggestion.reasonLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          CategorySelector(
            selected: _selected,
            onSelected: (c) => setState(() => _selected = c),
            label: null,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pop(context, _selected),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              backgroundColor: AppColors.ui,
              foregroundColor: AppColors.textOnPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
