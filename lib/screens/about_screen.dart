import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/brand.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_decorations.dart';
import '../core/theme/app_spacing.dart';
import '../widgets/app_logo_mark.dart';
import '../widgets/glass_container.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _vawcomUrl = 'https://vawcom.com';

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const AboutScreen()),
    );
  }

  Future<void> _openVawcom(BuildContext context) async {
    HapticFeedback.lightImpact();
    final uri = Uri.parse(_vawcomUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open vawcom.com')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppBackground(),
          SafeArea(
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
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                          color: AppColors.textSecondary,
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              const AppAccentBar(height: 22),
                              const SizedBox(width: 10),
                              Text(
                                'About',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
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
                      20,
                      AppSpacing.pageH,
                      AppSpacing.navBottom,
                    ),
                    child: Column(
                      children: [
                        _AboutHero(theme: theme),
                        const SizedBox(height: AppSpacing.section),
                        _AboutContentCard(
                          theme: theme,
                          onOpenVawcom: () => _openVawcom(context),
                        ),
                      ],
                    ),
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

class _AboutHero extends StatelessWidget {
  const _AboutHero({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      radius: AppRadius.xl,
      blur: 14,
      accentGlow: true,
      tint: AppColors.glassFillStrong,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.glassHighlight,
                  AppColors.glassFillStrong,
                ],
              ),
              border: Border.all(color: AppColors.glassBorder),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ui.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(
              child: AppLogoMark(size: 52),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            AppBrand.nameWithDot,
            style: theme.textTheme.headlineMedium?.copyWith(
              letterSpacing: -0.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cash flow tracker for everyday spending',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: AppDecorations.pillChip(),
            child: Text(
              'LOCAL · PRIVATE · YOUR DEVICE',
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.textSecondary,
                fontSize: 9.5,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutContentCard extends StatelessWidget {
  const _AboutContentCard({
    required this.theme,
    required this.onOpenVawcom,
  });

  final ThemeData theme;
  final VoidCallback onOpenVawcom;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            theme: theme,
            title: 'Creator',
            accent: AppColors.ui,
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.ui.withValues(alpha: 0.22),
                      AppColors.ui.withValues(alpha: 0.06),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.ui.withValues(alpha: 0.28),
                  ),
                ),
                child: Center(
                  child: Text(
                    'A',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppColors.ui,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hi, I\'m Arham',
                      style: theme.textTheme.titleLarge?.copyWith(
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Creator of ${AppBrand.name}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'I built ${AppBrand.name} to make tracking everyday spending simple — '
                      'automatically from your notifications, with everything staying on your device.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 22),
          _SectionHeader(
            theme: theme,
            title: 'Vawcom',
            subtitle: 'AI agency',
            accent: AppColors.brand,
          ),
          const SizedBox(height: 16),
          Text(
            'When I\'m not building apps like this, I run Vawcom — '
            'an AI agency helping businesses build with artificial intelligence.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 16),
          _WebsiteLink(onTap: onOpenVawcom),
          const SizedBox(height: 22),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 18),
          GlassContainer(
            radius: AppRadius.lg,
            blur: 8,
            tint: AppColors.glassFill,
            padding: const EdgeInsets.all(16),
            showShadow: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: AppDecorations.iconBadge(AppColors.ui),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: AppColors.ui,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Privacy first',
                        style: theme.textTheme.titleMedium?.copyWith(
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'All your data stays on your device. '
                        '${AppBrand.name} does not upload transactions to any server.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                          height: 1.5,
                        ),
                      ),
                    ],
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.theme,
    required this.title,
    required this.accent,
    this.subtitle,
  });

  final ThemeData theme;
  final String title;
  final String? subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ColoredAccentBar(color: accent, height: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  letterSpacing: -0.3,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ColoredAccentBar extends StatelessWidget {
  const _ColoredAccentBar({required this.color, required this.height});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.95),
            color.withValues(alpha: 0.35),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

class _WebsiteLink extends StatelessWidget {
  const _WebsiteLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.brand.withValues(alpha: 0.14),
                AppColors.glassFillStrong,
              ],
            ),
            border: Border.all(
              color: AppColors.brand.withValues(alpha: 0.32),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: AppDecorations.iconBadge(AppColors.brand),
                  child: const Icon(
                    Icons.language_rounded,
                    color: AppColors.brand,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'vawcom.com',
                        style: theme.textTheme.titleMedium?.copyWith(
                          letterSpacing: -0.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Visit the Vawcom website',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: AppDecorations.pillChip(
                    fill: AppColors.brand.withValues(alpha: 0.12),
                    border: AppColors.brand.withValues(alpha: 0.28),
                  ),
                  child: Text(
                    'Open',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.brand,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
