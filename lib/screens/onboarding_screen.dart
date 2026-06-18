import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/brand.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_decorations.dart';
import '../core/theme/app_spacing.dart' show AppRadius;
import '../features/ingest/ingest_service.dart';
import '../widgets/app_logo_mark.dart';
import '../widgets/glass_container.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  final Future<void> Function() onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  static const _pageCount = 4;

  final _pageController = PageController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<IngestService>().refreshNotificationAccess();
    }
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: _SetupHeader(
                    page: _page,
                    pageCount: _pageCount,
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _page = i),
                    children: const [
                      _WelcomeStep(),
                      _InfoStep(
                        icon: Icons.shield_outlined,
                        eyebrow: 'Private by design',
                        title: 'Your data stays\non this device',
                        body:
                            'HISAAB is built for privacy. Everything you track lives locally on your phone — not on our servers.',
                        features: [
                          _SetupFeature(
                            icon: Icons.phone_iphone_rounded,
                            title: 'On-device storage',
                            subtitle:
                                'Transactions, categories, and reports are saved in your app only.',
                          ),
                          _SetupFeature(
                            icon: Icons.cloud_off_rounded,
                            title: 'No account required',
                            subtitle:
                                'No sign-up, no cloud sync, and nothing uploaded without your action.',
                          ),
                          _SetupFeature(
                            icon: Icons.lock_outline_rounded,
                            title: 'You stay in control',
                            subtitle:
                                'Export a backup or clear data anytime from Settings.',
                          ),
                        ],
                      ),
                      _InfoStep(
                        icon: Icons.auto_awesome_rounded,
                        eyebrow: 'Hands-free tracking',
                        title: 'Spending logged\nautomatically',
                        body:
                            'Grant access once and HISAAB reads payment alerts in the background — you just review and confirm.',
                        features: [
                          _SetupFeature(
                            icon: Icons.notifications_active_outlined,
                            title: 'Bank & wallet alerts',
                            subtitle:
                                'Bank, wallet, and payment app notifications (Google Wallet, JazzCash, UBL, etc.) are parsed on-device.',
                          ),
                          _SetupFeature(
                            icon: Icons.sms_outlined,
                            title: 'SMS fallback',
                            subtitle:
                                'Transaction texts can be read locally when alerts arrive by SMS.',
                          ),
                          _SetupFeature(
                            icon: Icons.inbox_outlined,
                            title: 'Quick review',
                            subtitle:
                                'Pending items land in your Inbox — accept or reject in one tap.',
                          ),
                        ],
                      ),
                      _SetupSourcesStep(),
                    ],
                  ),
                ),
                _SetupFooter(
                  page: _page,
                  pageCount: _pageCount,
                  onContinue: _next,
                  onSkip: widget.onComplete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _next() async {
    if (_page < _pageCount - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await widget.onComplete();
  }
}

class _SetupHeader extends StatelessWidget {
  const _SetupHeader({required this.page, required this.pageCount});

  final int page;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (page + 1) / pageCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const AppLogoMark(size: 18, color: AppColors.brand),
            const SizedBox(width: 8),
            Text(
              AppBrand.name,
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.brand,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            GlassContainer(
              radius: AppRadius.pill,
              blur: 10,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              showShadow: false,
              child: Text(
                'Step ${page + 1} of $pageCount',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: SizedBox(
            height: 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: AppColors.surfaceHigh),
                AnimatedAlign(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.centerLeft,
                  widthFactor: progress.clamp(0.08, 1.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      gradient: LinearGradient(
                        colors: [
                          AppColors.ui.withValues(alpha: 0.95),
                          AppColors.ui.withValues(alpha: 0.55),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.ui.withValues(alpha: 0.25),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
      child: Column(
        children: [
          const SizedBox(height: 12),
          GlassContainer(
            radius: AppRadius.hero,
            blur: 16,
            accentGlow: true,
            padding: const EdgeInsets.all(32),
            child: const AppLogoMark(
              size: 72,
              emphasized: true,
            ),
          ),
          const SizedBox(height: 36),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: theme.textTheme.headlineLarge?.copyWith(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                height: 1.05,
                color: AppColors.textPrimary,
              ),
              children: const [
                TextSpan(text: 'Welcome to\n'),
                TextSpan(
                  text: AppBrand.nameWithDot,
                  style: TextStyle(color: AppColors.brand),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Your personal cash-flow tracker for PKR — built to feel effortless from day one.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          const _FeatureHighlight(
            icon: Icons.speed_rounded,
            text: 'Set up takes under a minute',
          ),
        ],
      ),
    );
  }
}

class _InfoStep extends StatelessWidget {
  const _InfoStep({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.features,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;
  final List<_SetupFeature> features;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassContainer(
                radius: AppRadius.xl,
                blur: 14,
                accentGlow: true,
                padding: const EdgeInsets.all(18),
                child: Icon(icon, size: 32, color: AppColors.ui),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow.toUpperCase(),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppColors.textMuted,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            body,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SetupFeatureTile(feature: f),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupFeature {
  const _SetupFeature({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

class _SetupFeatureTile extends StatelessWidget {
  const _SetupFeatureTile({required this.feature});

  final _SetupFeature feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassContainer(
      radius: AppRadius.lg,
      blur: 10,
      tint: AppColors.glassFillStrong,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      showShadow: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: AppDecorations.iconBadge(AppColors.ui),
            child: Icon(feature.icon, size: 18, color: AppColors.ui),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  feature.subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    height: 1.4,
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

class _FeatureHighlight extends StatelessWidget {
  const _FeatureHighlight({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      radius: AppRadius.lg,
      blur: 10,
      tint: AppColors.glassFillStrong,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      showShadow: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.ui),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupSourcesStep extends StatefulWidget {
  const _SetupSourcesStep();

  @override
  State<_SetupSourcesStep> createState() => _SetupSourcesStepState();
}

class _SetupSourcesStepState extends State<_SetupSourcesStep>
    with WidgetsBindingObserver {
  bool _smsGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshSms();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshSms();
    }
  }

  Future<void> _refreshSms() async {
    if (!Platform.isAndroid) return;
    final status = await Permission.sms.status;
    if (!mounted) return;
    setState(() {
      _smsGranted = status.isGranted || status.isLimited;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<IngestService>(
      builder: (context, ingest, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppAccentBar(height: 52),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CONNECT SOURCES',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: AppColors.textMuted,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Enable access to\nautomate tracking',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'These permissions stay on your device. HISAAB only reads payment-related alerts — nothing else.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              _PermissionCard(
                icon: Icons.notifications_active_outlined,
                title: 'Notification access',
                subtitle:
                    'Required on Android to capture bank and wallet payment alerts automatically.',
                enabled: Platform.isAndroid && ingest.hasNotificationAccessGranted,
                recommended: true,
                actionLabel: Platform.isAndroid ? 'Open settings' : 'Not available',
                onAction: Platform.isAndroid
                    ? () async {
                        final ok = await ingest.hasNotificationAccess();
                        if (!ok) await ingest.openNotificationSettings();
                        await ingest.refreshNotificationAccess();
                        await ingest.requestBatteryOptimizationExemption();
                      }
                    : null,
              ),
              if (Platform.isAndroid) ...[
                const SizedBox(height: 10),
                _PermissionCard(
                  icon: Icons.sms_outlined,
                  title: 'SMS access',
                  subtitle:
                      'Optional — reads transaction SMS when apps send alerts by text.',
                  enabled: _smsGranted,
                  actionLabel: 'Allow SMS',
                  onAction: () async {
                    await Permission.sms.request();
                    await _refreshSms();
                  },
                ),
              ],
              const SizedBox(height: 10),
              _PermissionCard(
                icon: Icons.mail_outline_rounded,
                title: 'Gmail',
                subtitle:
                    'Optional — sync email alerts from banks and payment services.',
                enabled: ingest.isGmailConnected,
                actionLabel: ingest.isGmailConnected ? 'Connected' : 'Connect',
                onAction: ingest.isGmailConnected
                    ? null
                    : () => ingest.connectGmail(),
              ),
              const SizedBox(height: 16),
              const _FeatureHighlight(
                icon: Icons.privacy_tip_outlined,
                text: 'You can change these anytime in Settings',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.actionLabel,
    this.recommended = false,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final bool recommended;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = enabled ? AppColors.income : AppColors.textMuted;

    return GlassContainer(
      radius: AppRadius.lg,
      blur: 12,
      tint: AppColors.glassFillStrong,
      accentGlow: enabled,
      padding: const EdgeInsets.all(14),
      showShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: AppDecorations.iconBadge(
                  enabled ? AppColors.income : AppColors.ui,
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: enabled ? AppColors.income : AppColors.ui,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (recommended && !enabled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: AppDecorations.pillChip(),
                            child: Text(
                              'Recommended',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                enabled ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 16,
                color: statusColor,
              ),
              const SizedBox(width: 6),
              Text(
                enabled ? 'Enabled' : 'Not set up',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              if (onAction != null && !enabled)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                  child: Text(actionLabel),
                )
              else if (enabled)
                Text(
                  actionLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.income,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SetupFooter extends StatelessWidget {
  const _SetupFooter({
    required this.page,
    required this.pageCount,
    required this.onContinue,
    required this.onSkip,
  });

  final int page;
  final int pageCount;
  final VoidCallback onContinue;
  final Future<void> Function() onSkip;

  @override
  Widget build(BuildContext context) {
    final isLast = page == pageCount - 1;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < pageCount; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: page == i ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    color: page == i
                        ? AppColors.ui
                        : AppColors.surfaceHigh,
                    boxShadow: page == i
                        ? [
                            BoxShadow(
                              color: AppColors.ui.withValues(alpha: 0.25),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              color: AppColors.ui,
              boxShadow: AppDecorations.heroGlow(),
            ),
            child: FilledButton(
              onPressed: onContinue,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
                backgroundColor: Colors.transparent,
                foregroundColor: AppColors.textOnPrimary,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: Text(isLast ? 'Enter HISAAB' : 'Continue'),
            ),
          ),
          if (isLast) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => onSkip(),
              child: Text(
                'Skip setup for now',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
