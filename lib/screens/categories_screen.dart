import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_decorations.dart';
import '../core/theme/app_spacing.dart';
import '../models/category_info.dart';
import '../models/transaction.dart';
import '../providers/category_catalog.dart';
import '../providers/transaction_provider.dart';
import '../widgets/category_selector.dart';
import '../widgets/glass_container.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const CategoriesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppBackground(),
          SafeArea(
            child: Consumer<CategoryCatalog>(
              builder: (context, catalog, _) {
                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back_rounded),
                              color: AppColors.textSecondary,
                            ),
                            const AppAccentBar(height: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Categories',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(letterSpacing: -0.3),
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
                          8,
                          AppSpacing.pageH,
                          12,
                        ),
                        child: Text(
                          'Built-in categories are always available. Add your own '
                          'for anything that does not fit the defaults.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textMuted,
                              ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.pageH,
                        ),
                        child: _SectionHeader(title: 'Built-in'),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageH,
                        8,
                        AppSpacing.pageH,
                        20,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final category = catalog.builtIn[index];
                            return _CategoryRow(
                              category: category,
                              showChevron: false,
                            );
                          },
                          childCount: catalog.builtIn.length,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.pageH,
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: _SectionHeader(title: 'Your categories'),
                            ),
                            TextButton.icon(
                              onPressed: () => _showEditor(context),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Add'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (catalog.custom.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.pageH,
                            0,
                            AppSpacing.pageH,
                            24,
                          ),
                          child: GlassCard(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'No custom categories yet. Tap Add to create one.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.textMuted),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.pageH,
                          8,
                          AppSpacing.pageH,
                          32,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final category = catalog.custom[index];
                              return _CategoryRow(
                                category: category,
                                onTap: () => _showEditor(
                                  context,
                                  existing: category,
                                ),
                                onDelete: () => _deleteCategory(context, category),
                              );
                            },
                            childCount: catalog.custom.length,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditor(
    BuildContext context, {
    CategoryInfo? existing,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CategoryEditorSheet(existing: existing),
    );
  }

  Future<void> _deleteCategory(
    BuildContext context,
    CategoryInfo category,
  ) async {
    final provider = context.read<TransactionProvider>();
    final count = provider.countForCategory(category.id);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
          count == 0
              ? '"${category.label}" will be removed.'
              : '$count transaction${count == 1 ? '' : 's'} using '
                  '"${category.label}" will move to Other.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.ui),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final catalog = context.read<CategoryCatalog>();
    if (count > 0) {
      await provider.reassignCategory(
        category.id,
        SpendingCategory.other.storageKey,
      );
    }
    await catalog.removeCustom(category.id);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const AppAccentBar(height: 16),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.textMuted,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    this.onTap,
    this.onDelete,
    this.showChevron = true,
  });

  final CategoryInfo category;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: AppDecorations.iconBadge(category.color),
                    child: Icon(category.icon, color: category.color, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.label,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (category.isCustom)
                          Text(
                            'Custom',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textMuted,
                                ),
                          ),
                      ],
                    ),
                  ),
                  if (onDelete != null)
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded),
                      color: AppColors.textMuted,
                      tooltip: 'Delete',
                    )
                  else if (showChevron && onTap != null)
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textDim,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryEditorSheet extends StatefulWidget {
  const _CategoryEditorSheet({this.existing});

  final CategoryInfo? existing;

  @override
  State<_CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<_CategoryEditorSheet> {
  late final TextEditingController _nameCtrl;
  late IconData _icon;
  late Color _color;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameCtrl = TextEditingController(text: existing?.label ?? '');
    _icon = existing?.icon ?? CategoryIconOptions.icons.first;
    _color = existing?.color ?? CategoryColorOptions.colors.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    final catalog = context.read<CategoryCatalog>();
    try {
      if (widget.existing == null) {
        await catalog.addCustom(name: name, icon: _icon, color: _color);
      } else {
        await catalog.updateCustom(
          id: widget.existing!.id,
          name: name,
          icon: _icon,
          color: _color,
        );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: sheetDecoration(),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(),
              Text(
                editing ? 'Edit category' : 'New category',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _nameCtrl,
                autofocus: !editing,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. Subscriptions',
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Icon',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CategoryIconOptions.icons.map((icon) {
                  final selected = icon.codePoint == _icon.codePoint;
                  return InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _icon = icon);
                    },
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: selected
                            ? _color.withValues(alpha: 0.2)
                            : AppColors.glassFillStrong,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: selected ? AppColors.ui : AppColors.glassBorder,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: selected ? _color : AppColors.textSecondary,
                        size: 22,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              Text(
                'Color',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: CategoryColorOptions.colors.map((color) {
                  final selected = color.toARGB32() == _color.toARGB32();
                  return InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _color = color);
                    },
                    customBorder: const CircleBorder(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? AppColors.textPrimary : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.45),
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                  backgroundColor: AppColors.ui,
                  foregroundColor: AppColors.textOnPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: Text(editing ? 'Save changes' : 'Add category'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
