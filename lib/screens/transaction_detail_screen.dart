import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/motion/app_haptics.dart';
import '../core/utils/formatters.dart';
import '../models/category_info.dart';
import '../models/transaction.dart';
import '../providers/category_catalog.dart';
import '../providers/transaction_provider.dart';
import '../widgets/app_back_button.dart';
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
  late String _merchant;
  late String? _description;
  late final TextEditingController _nameCtrl;
  late final FocusNode _nameFocus;
  late TransactionProvider _txProvider;
  bool _saving = false;
  bool _deleting = false;
  bool _savingNote = false;
  bool _savingName = false;
  bool _editingName = false;
  bool _committingName = false;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.transaction.categoryId;
    _merchant = widget.transaction.merchant;
    _description = widget.transaction.description;
    _nameCtrl = TextEditingController(text: _merchant);
    _nameFocus = FocusNode()..addListener(_handleNameFocus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _txProvider = context.read<TransactionProvider>();
  }

  @override
  void dispose() {
    _nameFocus.removeListener(_handleNameFocus);
    final pending = _nameCtrl.text.trim();
    if (_editingName && pending.isNotEmpty && pending != _merchant) {
      _txProvider.updateTransactionMerchant(widget.transaction.id, pending);
    }
    _nameFocus.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  CategoryInfo _category(BuildContext context) {
    return context.watch<CategoryCatalog>().resolve(_categoryId);
  }

  Future<void> _pickCategory() async {
    if (_saving || _deleting || _savingName) return;

    final picked = await showCategoryPickerSheet(
      context,
      selectedId: _categoryId,
      title: 'Change category',
    );
    if (picked == null || picked == _categoryId || !mounted) return;

    setState(() => _saving = true);
    AppHaptics.lightImpact();

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

  Future<void> _editDescription() async {
    if (_saving || _deleting || _savingNote || _savingName) return;

    final controller = TextEditingController(text: _description ?? '');
    final saved = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.backgroundElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Note',
                style: Theme.of(
                  ctx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 5,
                minLines: 3,
                style: Theme.of(ctx).textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'What was this for?',
                  hintStyle: Theme.of(
                    ctx,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surfaceMuted,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.borderLight),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if ((_description ?? '').isNotEmpty)
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, ''),
                      child: const Text('Remove'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.ui,
                      foregroundColor: AppColors.textOnPrimary,
                      minimumSize: const Size(80, 40),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || saved == null) return;

    setState(() => _savingNote = true);
    AppHaptics.lightImpact();

    final next = saved.isEmpty ? null : saved;
    await context.read<TransactionProvider>().updateTransactionDescription(
      widget.transaction.id,
      next,
    );

    if (!mounted) return;
    setState(() {
      _description = next;
      _savingNote = false;
    });
  }

  void _handleNameFocus() {
    if (_nameFocus.hasFocus || !_editingName || _committingName) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _nameFocus.hasFocus) return;
      _commitName();
    });
  }

  void _beginNameEdit() {
    if (_saving || _deleting || _savingNote || _savingName || _editingName) {
      return;
    }
    AppHaptics.selectionClick();
    setState(() => _editingName = true);
    _nameCtrl
      ..text = _merchant
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: _merchant.length,
      );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocus.requestFocus();
    });
  }

  Future<void> _commitName([String? raw]) async {
    if (_committingName || !_editingName) return;
    _committingName = true;
    final next = (raw ?? _nameCtrl.text).trim();
    if (mounted) setState(() => _editingName = false);
    if (_nameFocus.hasFocus) _nameFocus.unfocus();

    try {
      if (next.isEmpty || next == _merchant) {
        _nameCtrl.text = _merchant;
        return;
      }

      if (mounted) setState(() => _savingName = true);
      AppHaptics.lightImpact();
      await _txProvider.updateTransactionMerchant(widget.transaction.id, next);
      _merchant = next;
      _nameCtrl.text = next;
    } finally {
      _committingName = false;
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _leave() async {
    await _commitName();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    if (_saving || _deleting || _savingNote || _savingName) return;

    final tx = widget.transaction;
    final isDebit = tx.isDebit;
    final amountLabel =
        '${isDebit ? '−' : '+'}${formatCurrency(tx.amount, showDecimals: true)}';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text(
          '$amountLabel ${isDebit ? 'to' : 'from'} $_merchant will be '
          'removed. Your totals will update everywhere.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.expense,
              foregroundColor: AppColors.textPrimary,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    AppHaptics.mediumImpact();

    final deleted = await context.read<TransactionProvider>().deleteTransaction(
      tx.id,
    );

    if (!mounted) return;

    if (!deleted) {
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete transaction'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tx = widget.transaction;
    final category = _category(context);
    final isDebit = tx.isDebit;
    final failed = tx.isFailed;
    final amountColor = failed
        ? AppColors.textMuted
        : isDebit
            ? AppColors.textPrimary
            : AppColors.income;

    return PopScope(
      canPop: !_editingName,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _leave();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const AppBackground(),
            SafeArea(
              bottom: false,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        8,
                        4,
                        AppSpacing.pageH,
                        0,
                      ),
                      child: Row(
                        children: [
                          AppBackButton(onPressed: _leave),
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
                          Opacity(
                            opacity: failed ? 0.48 : 1,
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: (failed
                                        ? AppColors.textDim
                                        : category.color)
                                    .withValues(alpha: 0.14),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.lg),
                              ),
                              child: Icon(
                                category.icon,
                                color: failed
                                    ? AppColors.textDim
                                    : category.color,
                                size: 30,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _MerchantName(
                            editing: _editingName,
                            merchant: _merchant,
                            style: theme.textTheme.headlineMedium,
                            controller: _nameCtrl,
                            focusNode: _nameFocus,
                            onDoubleTap: _beginNameEdit,
                            onSubmitted: _commitName,
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
                                decoration: failed
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            failed
                                ? 'Failed payment · not counted'
                                : isDebit
                                    ? 'Expense'
                                    : 'Income',
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 6,
                        ),
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
                            if (tx.status != TransactionStatus.confirmed) ...[
                              const _DetailDivider(),
                              _DetailRow(
                                label: 'Status',
                                value: _StatusChip(status: tx.status),
                              ),
                            ],
                            const _DetailDivider(),
                            _NoteRow(
                              description: _description,
                              saving: _savingNote,
                              onTap: _editDescription,
                            ),
                          ],
                        ),
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
                      child: OutlinedButton.icon(
                        onPressed: (_saving || _deleting || _savingName)
                            ? null
                            : _confirmDelete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.expense,
                          disabledForegroundColor: AppColors.expense.withValues(
                            alpha: 0.45,
                          ),
                          minimumSize: const Size(double.infinity, 48),
                          side: BorderSide(
                            color: AppColors.expense.withValues(
                              alpha: _deleting ? 0.25 : 0.45,
                            ),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        icon: _deleting
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.expense.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                              ),
                        label: Text(
                          _deleting ? 'Deleting…' : 'Delete transaction',
                        ),
                      ),
                    ),
                  ),
                  if (tx.rawText != null && tx.rawText!.trim().isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.pageH,
                          AppSpacing.section,
                          AppSpacing.pageH,
                          AppSpacing.scrollBottom(context),
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
                    SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.scrollBottom(context)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatFullDate(DateTime date) {
    return DateFormat('EEEE, d MMMM yyyy').format(date);
  }
}

class _MerchantName extends StatelessWidget {
  const _MerchantName({
    required this.editing,
    required this.merchant,
    required this.style,
    required this.controller,
    required this.focusNode,
    required this.onDoubleTap,
    required this.onSubmitted,
  });

  final bool editing;
  final String merchant;
  final TextStyle? style;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onDoubleTap;
  final ValueChanged<String> onSubmitted;

  static const _fieldDecoration = InputDecoration(
    isDense: true,
    isCollapsed: true,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    filled: false,
    fillColor: Colors.transparent,
    contentPadding: EdgeInsets.zero,
    counterText: '',
  );

  @override
  Widget build(BuildContext context) {
    final nameStyle = style;

    if (!editing) {
      return GestureDetector(
        onDoubleTap: onDoubleTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(merchant, textAlign: TextAlign.center, style: nameStyle),
        ),
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: const InputDecorationTheme(
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: true,
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        maxLines: 2,
        minLines: 1,
        cursorColor: AppColors.ui,
        cursorWidth: 1.6,
        cursorRadius: const Radius.circular(1),
        style: nameStyle,
        inputFormatters: [LengthLimitingTextInputFormatter(80)],
        onSubmitted: onSubmitted,
        onTapOutside: (_) => onSubmitted(controller.text),
        decoration: _fieldDecoration,
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({
    required this.description,
    required this.saving,
    required this.onTap,
  });

  final String? description;
  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasNote = description != null && description!.trim().isNotEmpty;
    final action = TextButton(
      onPressed: saving ? null : onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textMuted,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: saving
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textMuted.withValues(alpha: 0.7),
              ),
            )
          : Text(
              hasNote ? 'Edit' : 'Add',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
    );

    if (!hasNote) {
      return _DetailRow(label: 'Note', value: action);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Note',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              action,
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description!.trim(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
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
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(alignment: Alignment.centerRight, child: value),
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
      TransactionStatus.failed => ('Failed', AppColors.textMuted),
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
