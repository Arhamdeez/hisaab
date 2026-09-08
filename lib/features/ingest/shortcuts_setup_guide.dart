import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/brand.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'ingest_service.dart';
import 'shortcuts_ingest.dart';

/// Plain-language walkthrough: test one SMS, then one Shortcuts automation.
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
  bool _importOk = false;
  bool _importing = false;
  String? _islandStatus;

  Future<void> _importClipboard() async {
    setState(() {
      _importing = true;
      _importStatus = null;
      _importOk = false;
    });
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (!mounted) return;
      if (text.isEmpty) {
        setState(() {
          _importStatus =
              'Nothing was copied. Open Messages, press and hold a payment SMS, tap Copy, then try again.';
        });
        return;
      }
      final ingest = context.read<IngestService>();
      final ok = await ingest.ingestShortcutText(text);
      if (!mounted) return;
      setState(() {
        _importOk = ok;
        _importStatus = ok
            ? 'It worked. Close this and look at Home — you should see the payment.'
            : 'Copied, but that text did not look like a payment. Copy the full SMS (the one with Rs / PKR) and try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _importStatus = 'Something went wrong. Copy the SMS again and retry.';
      });
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _openShortcutsApp() async {
    final uri = Uri.parse('shortcuts://');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
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
                      'Log payments automatically',
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
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  AppSpacing.scrollBottom(context, extra: 16),
                ),
                children: [
                  Text(
                    'Your iPhone will not let ${AppBrand.name} read bank apps. '
                    'That is an Apple rule.\n\n'
                    'So we use Apple’s free Shortcuts app. When a payment SMS arrives, '
                    'Shortcuts hands the text to ${AppBrand.name}. Takes a few minutes, once.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SectionCard(
                    emoji: '1',
                    title: 'Try it once (no Shortcuts yet)',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'This checks that ${AppBrand.name} can read a real payment SMS.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const _MiniStep(
                          number: '1',
                          text: 'Open Messages (green speech-bubble app).',
                        ),
                        const _MiniStep(
                          number: '2',
                          text:
                              'Find an SMS about money — JazzCash, EasyPaisa, or your bank. It should mention Rs or PKR.',
                        ),
                        const _MiniStep(
                          number: '3',
                          text: 'Press and hold that message. Tap Copy.',
                        ),
                        const _MiniStep(
                          number: '4',
                          text: 'Come back here. Tap the white button below.',
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
                                : 'Use the SMS I copied',
                          ),
                        ),
                        if (_importStatus != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _importStatus!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _importOk
                                  ? AppColors.income
                                  : AppColors.ui,
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
                    title: 'Make it automatic (do this once)',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Go slowly. Match the words in quotes.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: _openShortcutsApp,
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('Open the Shortcuts app'),
                        ),
                        const SizedBox(height: 14),
                        const _BigStep(
                          number: 1,
                          title: 'Go to Automation',
                          body:
                              'At the bottom of Shortcuts, tap “Automation”.\n'
                              'It may look like a clock.\n\n'
                              'If you only see “Shortcuts” and “Gallery”, look along the bottom for a third tab.',
                        ),
                        const _BigStep(
                          number: 2,
                          title: 'Start a new automation',
                          body:
                              'Tap the + at the top right.\n'
                              'Tap “New Automation” or “Create Personal Automation”.\n'
                              'Do not tap “Create Shortcut”.',
                        ),
                        const _BigStep(
                          number: 3,
                          title: 'Choose Message',
                          body:
                              'At the top, tap the search box. Type: Message\n'
                              'Tap “Message” (green bubble). On newer iPhones it may say “When I get a Message”.\n\n'
                              'If it asks who can send the message, tap “Anyone” (or leave Sender empty).\n\n'
                              'Tap Next.',
                        ),
                        const _BigStep(
                          number: 4,
                          title: 'Add “Log payment”',
                          body:
                              'Tap “Add Action” or the search box.\n'
                              'Type: Log payment\n'
                              'Tap “Log payment”. It should show ${AppBrand.name} under it.\n\n'
                              'If you do not see it: open ${AppBrand.name} once, wait 10 seconds, then search again.',
                        ),
                        const _BigStep(
                          number: 5,
                          title: 'Give it the SMS (do not skip)',
                          body:
                              'Look at the “Log payment” box.\n'
                              'If “Payment text” already says Shortcut Input or Message, you are done — skip to the next step.\n\n'
                              'If it looks empty: tap “Payment text”, then tap “Shortcut Input”.\n'
                              'If you see “Message” or “Received Message”, tap that instead.',
                        ),
                        const _BigStep(
                          number: 6,
                          title: 'Turn off the extra question',
                          body:
                              'Tap Next.\n\n'
                              'Turn OFF the switch “Ask Before Running”.\n'
                              'If a popup says “Don’t Ask?”, tap “Don’t Ask”.\n\n'
                              'On newer iPhones that switch is gone. Instead turn ON “Run Immediately”.\n\n'
                              'Tap Done.',
                        ),
                        _BigStep(
                          number: 7,
                          title: 'Check it',
                          body:
                              'Wait for the next payment SMS, or ask someone to send you Rs 1.\n'
                              '${AppBrand.name} should open and show the payment.\n\n'
                              'If iPhone asks “Open in ${AppBrand.name}?”, tap Open.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    emoji: '3',
                    title: 'Optional: tap the back of your iPhone',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Double-tap the back of the phone. HISAAB stays in the background. '
                          'iOS asks how much to log, on top of whatever app you are in. '
                          'Type the amount and you are done.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: () async {
                            final data = await Clipboard.getData(
                              Clipboard.kTextPlain,
                            );
                            final started =
                                await ShortcutsIngest.instance.startIsland(
                              clipboard: data?.text,
                            );
                            if (!mounted) return;
                            setState(() {
                              _islandStatus = started
                                  ? 'Look at the black pill at the top of the screen. Long-press it. HISAAB did not take over the screen.'
                                  : 'Could not show the island. Copy an SMS and use “Use the SMS I copied”, or turn on Live Activities for HISAAB in Settings.';
                            });
                          },
                          icon: const Icon(Icons.touch_app_rounded),
                          label: const Text('Show the island pill'),
                        ),
                        if (_islandStatus != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _islandStatus!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.ui,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        const _BigStep(
                          number: 1,
                          title: 'Open Back Tap',
                          body:
                              'On a real iPhone (not the Simulator):\n'
                              'Open the Settings app (grey gear).\n'
                              'Tap Accessibility → Touch → Back Tap.',
                        ),
                        const _BigStep(
                          number: 2,
                          title: 'Choose Double Tap',
                          body: 'Tap “Double Tap”.',
                        ),
                        _BigStep(
                          number: 3,
                          title: 'Pick Add amount',
                          body:
                              'Scroll. Under Shortcuts, tap “Add amount” (or “Log payment”).\n\n'
                              'Do not pick Open URL. That opens the full app.\n\n'
                              'If it is missing: open ${AppBrand.name} once, swipe Settings away, then try again.',
                        ),
                        const _BigStep(
                          number: 4,
                          title: 'How to use it',
                          body:
                              '1. Stay in whatever app you are using.\n'
                              '2. Double-tap the back of the phone.\n'
                              '3. Type the amount when iOS asks. HISAAB does not take over the screen.',
                        ),
                        const _BigStep(
                          number: 5,
                          title: 'How to test (Simulator)',
                          body:
                              'The Simulator cannot feel a tap on the back of the laptop, and a URL will always open the full app.\n\n'
                              'Open the Shortcuts app → tap Add amount (or Log payment with Payment text empty). You should only see the amount prompt.\n\n'
                              'Or tap “Show the island pill” above to try the black pill at the top.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    emoji: '?',
                    title: 'If it does not work',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No Shortcuts app?\n'
                          'Open the App Store. Search “Shortcuts”. Install the one from Apple (free).\n\n'
                          'SMS arrives but nothing happens?\n'
                          'Open Shortcuts → Automation. Tap your automation. Make sure it is on. '
                          'Ask Before Running must be OFF (or Run Immediately ON). '
                          'Open the Log payment box and check Payment text is Shortcut Input, not empty.\n\n'
                          'App opens but no payment on Home?\n'
                          'That text may not look like money. Copy an SMS that says Rs or PKR, then use “Use the SMS I copied”.\n\n'
                          'Cannot find “Log payment”?\n'
                          'Open ${AppBrand.name}, wait 10 seconds, search again. Old iPhones (before iOS 16) will not show this action — use “Use the SMS I copied” instead.\n\n'
                          'Still stuck?\n'
                          'You can always copy the SMS and tap “Use the SMS I copied”. Automation is extra, not required.',
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
