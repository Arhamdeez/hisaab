import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/brand.dart';
import '../core/motion.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';
import '../features/ingest/ingest_service.dart';
import '../features/ingest/shortcuts_ingest.dart';
import '../models/transaction.dart';
import '../providers/app_preferences.dart';
import '../providers/transaction_provider.dart';
import 'app_logo_mark.dart';

/// Wraps the navigator so Back Tap can draw above the rest of the app.
class CaptureIslandHost extends StatelessWidget {
  const CaptureIslandHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        const CaptureIslandOverlay(),
      ],
    );
  }
}

/// Dynamic Island–style prompt: compact pill, then “what do you want to add?”
class CaptureIslandOverlay extends StatelessWidget {
  const CaptureIslandOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CapturePrompt?>(
      valueListenable: ShortcutsIngest.instance.capturePrompt,
      builder: (context, prompt, _) {
        if (prompt == null) return const SizedBox.shrink();
        return _CaptureIsland(
          key: const ValueKey('capture-island'),
          prompt: prompt,
        );
      },
    );
  }
}

enum _IslandPhase { compact, expanded, success }

class _CaptureIsland extends StatefulWidget {
  const _CaptureIsland({super.key, required this.prompt});

  final CapturePrompt prompt;

  @override
  State<_CaptureIsland> createState() => _CaptureIslandState();
}

class _CaptureIslandState extends State<_CaptureIsland> {
  _IslandPhase _phase = _IslandPhase.compact;
  bool _typing = false;
  bool _busy = false;
  String? _status;
  var _type = TransactionType.debit;

  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _amountFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      AppHaptics.mediumImpact();
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (mounted) setState(() => _phase = _IslandPhase.expanded);
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  CapturePrompt get _prompt =>
      ShortcutsIngest.instance.capturePrompt.value ?? widget.prompt;

  String? get _clipboard {
    final text = _prompt.clipboardText?.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  void _dismiss() {
    FocusManager.instance.primaryFocus?.unfocus();
    ShortcutsIngest.instance.dismissCapture();
  }

  Future<void> _succeed(String message) async {
    AppHaptics.lightImpact();
    if (!mounted) return;
    setState(() {
      _phase = _IslandPhase.success;
      _status = message;
      _typing = false;
    });
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (mounted) _dismiss();
  }

  Future<void> _logClipboard() async {
    final text = _clipboard;
    if (text == null || _busy) return;
    setState(() => _busy = true);
    try {
      final ok = await context.read<IngestService>().ingestShortcutText(text);
      if (!mounted) return;
      if (ok) {
        await _succeed('Logged');
      } else {
        setState(() {
          _busy = false;
          _status = 'That copy does not look like a payment. Type an amount.';
          _typing = true;
        });
        _amountFocus.requestFocus();
      }
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveAmount() async {
    if (_busy) return;
    final amount = parseTransactionAmountInput(_amountCtrl.text);
    if (amount == null) {
      AppHaptics.heavyImpact();
      setState(() => _status = 'Enter an amount, like 500');
      return;
    }
    final note = _noteCtrl.text.trim();
    setState(() => _busy = true);
    try {
      await context.read<TransactionProvider>().addManualTransaction(
            amount: amount,
            merchant: note.isEmpty ? 'Added from Back Tap' : note,
            categoryId: SpendingCategory.other.storageKey,
            type: _type,
          );
      if (!mounted) return;
      await _succeed(_type == TransactionType.credit ? 'Money in logged' : 'Logged');
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final expanded = _phase != _IslandPhase.compact;
    final maxW = (media.size.width - 20).clamp(280.0, 392.0);
    final top = media.padding.top + 6;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedOpacity(
              duration: AppMotion.medium,
              opacity: expanded ? 1 : 0,
              child: GestureDetector(
                onTap: _dismiss,
                behavior: HitTestBehavior.opaque,
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: expanded ? 0.45 : 0),
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: AppMotion.medium,
            curve: AppMotion.easeOut,
            top: top,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                width: expanded ? maxW : 136,
                constraints: BoxConstraints(
                  maxHeight: media.size.height * 0.62,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xF2141416),
                  borderRadius: BorderRadius.circular(expanded ? 30 : 20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                    width: 0.6,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.55),
                      blurRadius: expanded ? 32 : 16,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: AppColors.brand.withValues(alpha: expanded ? 0.12 : 0),
                      blurRadius: 28,
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 360),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: _phase == _IslandPhase.compact
                        ? _compact()
                        : _phase == _IslandPhase.success
                            ? _success()
                            : _expanded(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compact() {
    return const SizedBox(
      height: 38,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppLogoMark(size: 16, emphasized: true),
          SizedBox(width: 8),
          Text(
            'Add',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _success() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.income, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _status ?? 'Logged',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _expanded(BuildContext context) {
    final theme = Theme.of(context);
    final clip = _clipboard;
    final trackInward = context.watch<AppPreferences>().trackInwardFlow;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const AppLogoMark(size: 18, emphasized: true),
              const SizedBox(width: 8),
              Text(
                AppBrand.name,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _dismiss,
                icon: const Icon(Icons.close_rounded, size: 20),
                color: AppColors.textMuted,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'What do you want to add?',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            clip == null
                ? 'Type an amount, or copy a payment SMS and try again.'
                : 'Use the text you copied, or type an amount.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
              height: 1.35,
            ),
          ),
          if (clip != null) ...[
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Text(
                  clip,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _busy ? null : _logClipboard,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: AppColors.ui,
                foregroundColor: AppColors.textOnPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(_busy ? 'Reading…' : 'Log copied SMS'),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _typing = !_typing;
                _status = null;
              });
              if (_typing) {
                Future<void>.delayed(const Duration(milliseconds: 80), () {
                  if (mounted) _amountFocus.requestFocus();
                });
              }
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(_typing ? 'Hide amount' : 'Type an amount'),
          ),
          if (_typing) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              focusNode: _amountFocus,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [PositiveAmountInputFormatter()],
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 22,
                letterSpacing: -0.4,
              ),
              decoration: InputDecoration(
                labelText: 'Amount (Rs)',
                hintText: '500',
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'What was it? (optional)',
                hintText: 'Lunch, fuel…',
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            if (trackInward) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _typeChip('Spent', TransactionType.debit)),
                  const SizedBox(width: 8),
                  Expanded(child: _typeChip('Received', TransactionType.credit)),
                ],
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _saveAmount,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: AppColors.ui,
                foregroundColor: AppColors.textOnPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Save'),
            ),
          ],
          if (_status != null && _phase == _IslandPhase.expanded) ...[
            const SizedBox(height: 8),
            Text(
              _status!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.warning,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _typeChip(String label, TransactionType type) {
    final on = _type == type;
    return GestureDetector(
      onTap: () {
        AppHaptics.selectionClick();
        setState(() => _type = type);
      },
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: on
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: on
                ? Colors.white.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: on ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
