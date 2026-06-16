import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

abstract final class AppDecorations {
  /// Standard surface — glass tint, hairline border, soft shadow.
  static BoxDecoration card({
    Color? color,
    double radius = AppRadius.lg,
    bool glow = false,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      color: color ?? AppColors.glassFillStrong,
      border: Border.all(color: AppColors.glassBorder, width: 0.85),
      boxShadow: glow
          ? [
              BoxShadow(
                color: AppColors.ui.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ]
          : [
              BoxShadow(
                color: AppColors.shadow.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
    );
  }

  /// Soft outer glow for hero / focal cards.
  static List<BoxShadow> heroGlow({Color? color}) => [
        BoxShadow(
          color: (color ?? AppColors.ui).withValues(alpha: 0.10),
          blurRadius: 36,
          spreadRadius: -6,
          offset: const Offset(0, 14),
        ),
        BoxShadow(
          color: AppColors.ui.withValues(alpha: 0.05),
          blurRadius: 48,
          spreadRadius: -12,
        ),
      ];

  static BoxDecoration iconBadge(Color color) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadius.md),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: 0.18),
          color.withValues(alpha: 0.06),
        ],
      ),
      border: Border.all(color: color.withValues(alpha: 0.28)),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.12),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  static BoxDecoration iconButton() {
    return BoxDecoration(
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
          color: AppColors.shadow.withValues(alpha: 0.35),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  static BoxDecoration pillChip({
    Color? fill,
    Color? border,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      color: fill ?? AppColors.glassFillStrong,
      border: Border.all(
        color: border ?? AppColors.glassBorder,
      ),
    );
  }
}

/// Vertical accent beside section titles.
class AppAccentBar extends StatelessWidget {
  const AppAccentBar({super.key, this.height = 22});

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
            AppColors.ui.withValues(alpha: 0.95),
            AppColors.ui.withValues(alpha: 0.35),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.ui.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

/// Compact tappable chip for section actions ("View all").
class AppActionChip extends StatelessWidget {
  const AppActionChip({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Ink(
          decoration: AppDecorations.pillChip(),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
