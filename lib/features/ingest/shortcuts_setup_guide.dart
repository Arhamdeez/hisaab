import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/brand.dart';
import '../../core/theme/app_colors.dart';
import 'shortcuts_ingest.dart';

/// Bottom sheet / guide explaining how to feed SMS into HISAAB via Shortcuts.
abstract final class ShortcutsSetupGuide {
  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final bottom = MediaQuery.viewInsetsOf(ctx).bottom;

        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Material(
            color: const Color(0xFF1A1010),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Apple Shortcuts setup',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'iOS cannot read bank app notifications. Use Shortcuts to '
                      'forward wallet/bank SMS into ${AppBrand.name} — same parser '
                      'as Android, on-device only.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._steps.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.ui.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${entry.key + 1}',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ui,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Open URL action',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      '${ShortcutsIngest.importUrlPrefix}'
                      '[Message Content URL Encoded]',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          const ClipboardData(
                            text: ShortcutsIngest.importUrlPrefix,
                          ),
                        );
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Copied hisaab://import?text= — paste in Shortcuts, '
                              'then append URL-encoded message text.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy URL prefix'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static const _steps = [
    'Open the Shortcuts app → Automation → + → Message',
    'When I receive a message from your bank/wallet senders '
        '(JazzCash, EasyPaisa, 3737, 8558, etc.)',
    'Add action: URL Encode → Message Content (or Get Text from Input)',
    'Add action: Open URL → hisaab://import?text= then append the encoded text',
    'Turn off Ask Before Running if you want hands-free capture',
  ];
}
