import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/brand.dart';
import '../../core/theme/app_colors.dart';
import 'ingest_service.dart';
import 'shortcuts_ingest.dart';

/// Kid-simple walkthrough: prove import works, then build the Message automation.
abstract final class ShortcutsSetupGuide {
  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final height = MediaQuery.sizeOf(ctx).height;
        return SizedBox(
          height: height * 0.92,
          child: const _ShortcutsSetupSheet(),
        );
      },
    );
  }
}

class _ShortcutsSetupSheet extends StatefulWidget {
  const _ShortcutsSetupSheet();

  @override
  State<_ShortcutsSetupSheet> createState() => _ShortcutsSetupSheetState();
}

class _ShortcutsSetupSheetState extends State<_ShortcutsSetupSheet> {
  String? _importStatus;
  bool _importing = false;

  Future<void> _importClipboard() async {
    setState(() {
      _importing = true;
      _importStatus = null;
    });
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (!mounted) return;
      if (text.isEmpty) {
        setState(() {
          _importStatus =
              'Clipboard is empty. Open Messages, copy a JazzCash / EasyPaisa SMS, then try again.';
        });
        return;
      }
      final ingest = context.read<IngestService>();
      final ok = await ingest.ingestShortcutText(text);
      if (!mounted) return;
      setState(() {
        _importStatus = ok
            ? 'Done! Close this and check Home / Transactions. If nothing appeared, that SMS may not look like a payment.'
            : 'Could not read that text as a payment. Try copying a full bank or wallet SMS.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _importStatus = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _openShortcutsApp() async {
    final uri = Uri.parse('shortcuts://');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _copyPrefix() async {
    await Clipboard.setData(
      const ClipboardData(text: ShortcutsIngest.importUrlPrefix),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied. You will paste this in step 8.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: const Color(0xFF1A1010),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Set up auto-tracking',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  Text(
                    'On iPhone, ${AppBrand.name} cannot read your bank app by itself. '
                    'We use Apple’s free Shortcuts app so when a payment SMS arrives, '
                    'it opens ${AppBrand.name} with that text.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SectionCard(
                    emoji: '1',
                    title: 'First: try it once (easy)',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'This proves ${AppBrand.name} can read a payment SMS. No Shortcuts yet.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const _MiniStep(
                          number: 'A',
                          text:
                              'Open the Messages app (the green bubble app).',
                        ),
                        const _MiniStep(
                          number: 'B',
                          text:
                              'Find a JazzCash, EasyPaisa, or bank SMS about money sent or received.',
                        ),
                        const _MiniStep(
                          number: 'C',
                          text:
                              'Touch and hold the message → tap Copy.',
                        ),
                        const _MiniStep(
                          number: 'D',
                          text:
                              'Come back here and tap the orange button below.',
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _importing ? null : _importClipboard,
                          icon: _importing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.content_paste_go_rounded),
                          label: Text(
                            _importing
                                ? 'Reading…'
                                : 'Import the SMS I just copied',
                          ),
                        ),
                        if (_importStatus != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _importStatus!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.ui,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    emoji: '2',
                    title: 'Then: make it automatic',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Do these steps slowly. Look for the exact words in bold.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: _openShortcutsApp,
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('Open Shortcuts app'),
                        ),
                        const SizedBox(height: 14),
                        const _BigStep(
                          number: 1,
                          title: 'Open Automations',
                          body:
                              'In Shortcuts, tap Automation at the bottom '
                              '(looks like a clock / two arrows). '
                              'If you only see “Gallery” and “Shortcuts”, swipe the bottom tabs.',
                        ),
                        const _BigStep(
                          number: 2,
                          title: 'Make a new automation',
                          body:
                              'Tap the + (plus) in the top right. '
                              'Then choose Create Personal Automation '
                              '(not “Create Shortcut”).',
                        ),
                        const _BigStep(
                          number: 3,
                          title: 'Choose Message',
                          body:
                              'Scroll the list and tap Message '
                              '(green speech bubble).',
                        ),
                        const _BigStep(
                          number: 4,
                          title: 'When a message arrives',
                          body:
                              'Turn ON “Message Contains” OR leave senders open.\n\n'
                              'Easiest for beginners: leave “Sender” empty so '
                              'every SMS can run the shortcut (you can narrow it later).\n\n'
                              'Or tap Sender and add numbers like 3737, 8558, '
                              'JazzCash, EasyPaisa if you know them.\n\n'
                              'Tap Next.',
                        ),
                        const _BigStep(
                          number: 5,
                          title: 'Add the first action: URL Encode',
                          body:
                              'Tap Add Action.\n'
                              'In the search box type: URL Encode\n'
                              'Tap URL Encode.\n\n'
                              'Tap the small word where it says “Text” / input.\n'
                              'Choose Shortcut Input '
                              '(that is the SMS text).',
                        ),
                        const _BigStep(
                          number: 6,
                          title: 'Add the second action: URL',
                          body:
                              'Tap Add Action again.\n'
                              'Search: URL\n'
                              'Tap URL (not “Get Contents of URL”).\n\n'
                              'Clear the box and type exactly:\n'
                              'hisaab://import?text=\n'
                              '(no spaces)',
                        ),
                        const SizedBox(height: 4),
                        OutlinedButton.icon(
                          onPressed: _copyPrefix,
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('Copy hisaab://import?text='),
                        ),
                        const SizedBox(height: 12),
                        const _BigStep(
                          number: 7,
                          title: 'Stick the encoded SMS onto that URL',
                          body:
                              'Tap in the URL box after text=\n'
                              'Tap Select Variable / Shortcut Input area.\n'
                              'Choose Encoded Text '
                              '(from the URL Encode step).\n\n'
                              'You should see something like:\n'
                              'hisaab://import?text=Encoded Text',
                        ),
                        const _BigStep(
                          number: 8,
                          title: 'Open that URL',
                          body:
                              'Tap Add Action.\n'
                              'Search: Open URLs\n'
                              'Tap Open URLs.\n'
                              'Make sure it uses the URL you just built '
                              '(not a blank web address).',
                        ),
                        const _BigStep(
                          number: 9,
                          title: 'Turn off “Ask Before Running”',
                          body:
                              'Tap Next.\n'
                              'Find Ask Before Running and turn it OFF.\n'
                              'Confirm Don’t Ask if iPhone asks.\n\n'
                              'Then tap Done.',
                        ),
                        _BigStep(
                          number: 10,
                          title: 'Test it',
                          body:
                              'Ask a friend to send you a tiny JazzCash / EasyPaisa payment, '
                              'or wait for your next real SMS.\n\n'
                              '${AppBrand.name} should open by itself and log the payment.\n\n'
                              'If iPhone asks “Open in ${AppBrand.name}?”, tap Open.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    emoji: '?',
                    title: 'Stuck? Try this',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• Shortcuts app missing? Download “Shortcuts” from the App Store (Apple’s app, free).\n\n'
                          '• Nothing happens on SMS? Open the automation → make sure it is Enabled. '
                          'Run the “Import copied SMS” test above first.\n\n'
                          '• ${AppBrand.name} opens but no transaction? The SMS may not be a payment alert — try another message.\n\n'
                          '• Still hard? Use Import copied SMS each time for now — automation is optional.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.emoji,
    required this.title,
    required this.child,
  });

  final String emoji;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.ui.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  emoji,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ui,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _MiniStep extends StatelessWidget {
  const _MiniStep({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number.',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.ui,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _BigStep extends StatelessWidget {
  const _BigStep({
    required this.number,
    required this.title,
    required this.body,
  });

  final int number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.brand,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
