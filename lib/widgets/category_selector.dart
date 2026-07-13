import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_decorations.dart';
import '../core/theme/app_spacing.dart';
import '../models/category_info.dart';
import '../models/transaction.dart';
import '../providers/category_catalog.dart';

/// Frosted picker for spending categories (built-in + custom).
///
/// [compact] uses small wrap chips (Add sheet). Default grid is for confirm sheets.
class CategorySelector extends StatelessWidget {
  const CategorySelector({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    this.label = 'Category',
    this.compact = false,
  });

  final List<CategoryInfo> categories;
  final String selectedId;
  final ValueChanged<String> onSelected;
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
            children: categories.map((category) {
              return _CategoryChip(
                category: category,
                selected: selectedId == category.id,
                onTap: () => onSelected(category.id),
              );
            }).toList(),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (context, index) {
              final category = categories[index];
              return _CategoryTile(
                category: category,
                selected: selectedId == category.id,
                onTap: () => onSelected(category.id),
              );
            },
          ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final CategoryInfo category;
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

  final CategoryInfo category;
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
          child: Column(
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

/// Compact bottom sheet — tap a chip to pick and dismiss.
Future<String?> showCategoryPickerSheet(
  BuildContext context, {
  required String selectedId,
  String title = 'Choose category',
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final maxH = MediaQuery.sizeOf(ctx).height * 0.52;
      return Container(
        constraints: BoxConstraints(maxHeight: maxH),
        decoration: sheetDecoration(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: _CategoryPickerSheet(
          title: title,
          selectedId: selectedId,
        ),
      );
    },
  );
}

class _CategoryPickerSheet extends StatelessWidget {
  const _CategoryPickerSheet({
    required this.title,
    required this.selectedId,
  });

  final String title;
  final String selectedId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catalog = context.watch<CategoryCatalog>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHandle(),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        Flexible(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: CategorySelector(
              categories: catalog.all,
              selectedId: selectedId,
              compact: true,
              label: null,
              onSelected: (id) {
                HapticFeedback.selectionClick();
                Navigator.pop(context, id);
              },
            ),
          ),
        ),
      ],
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
