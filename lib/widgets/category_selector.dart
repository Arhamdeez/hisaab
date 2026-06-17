import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_decorations.dart';
import '../core/theme/app_spacing.dart';
import '../models/transaction.dart';

/// Frosted picker for [SpendingCategory].
///
/// [compact] uses small wrap chips (Add sheet). Default grid is for confirm sheets.
class CategorySelector extends StatelessWidget {
  const CategorySelector({
    super.key,
    required this.selected,
    required this.onSelected,
    this.label = 'Category',
    this.compact = false,
  });

  final SpendingCategory selected;
  final ValueChanged<SpendingCategory> onSelected;
  final String? label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: compact ? 10 : 12),
        ],
        if (compact)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SpendingCategory.values.map((category) {
              return _CategoryChip(
                category: category,
                selected: selected == category,
                onTap: () => onSelected(category),
              );
            }).toList(),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: SpendingCategory.values.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (context, index) {
              final category = SpendingCategory.values[index];
              return _CategoryTile(
                category: category,
                selected: selected == category,
                onTap: () => onSelected(category),
              );
            },
          ),
      ],
    );
  }
}

/// Compact pill — used in the Add transaction sheet.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final SpendingCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = category.color;

    return Material(
      color: Colors.transparent,
        child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            color: selected
                ? color.withValues(alpha: 0.2)
                : AppColors.glassFillStrong,
            border: Border.all(
              color: selected ? AppColors.ui : AppColors.glassBorder,
              width: 1.5,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                category.icon,
                size: 16,
                color: selected ? color : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                category.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontSize: 12.5,
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 5),
              SizedBox(
                width: 14,
                height: 14,
                child: AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: AppColors.ui,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final SpendingCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = category.color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            color: selected
                ? color.withValues(alpha: 0.18)
                : AppColors.glassFillStrong,
            border: Border.all(
              color: selected ? AppColors.ui : AppColors.glassBorder,
              width: 1.5,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: AppDecorations.iconBadge(color),
                    child: Icon(category.icon, size: 18, color: color),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    category.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 2,
                right: 2,
                child: AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: AppColors.ui,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cash in / cash out toggle styled like the rest of the app.
class CashFlowTypeSelector extends StatelessWidget {
  const CashFlowTypeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final TransactionType selected;
  final ValueChanged<TransactionType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _FlowOption(
            label: 'Cash out',
            icon: Icons.south_west_rounded,
            accent: AppColors.expense,
            selected: selected == TransactionType.debit,
            onTap: () => onChanged(TransactionType.debit),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _FlowOption(
            label: 'Cash in',
            icon: Icons.north_east_rounded,
            accent: AppColors.income,
            selected: selected == TransactionType.credit,
            onTap: () => onChanged(TransactionType.credit),
          ),
        ),
      ],
    );
  }
}

class _FlowOption extends StatelessWidget {
  const _FlowOption({
    required this.label,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            color: selected
                ? accent.withValues(alpha: 0.16)
                : AppColors.glassFillStrong,
            border: Border.all(
              color: selected ? AppColors.ui : AppColors.glassBorder,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? accent : AppColors.textSecondary,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontSize: 13,
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 5),
              SizedBox(
                width: 15,
                height: 15,
                child: AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(Icons.check_rounded, size: 15, color: accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared drag handle + sheet chrome for bottom sheets.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    );
  }
}

/// Standard elevated sheet container decoration.
BoxDecoration sheetDecoration() => const BoxDecoration(
      color: AppColors.backgroundElevated,
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      border: Border(top: BorderSide(color: AppColors.borderLight)),
    );
