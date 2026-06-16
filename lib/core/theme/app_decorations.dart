import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

abstract final class AppDecorations {
  /// Standard surface — quiet fill, hairline border, soft wine-tinted shadow.
  static BoxDecoration card({
    Color? color,
    double radius = AppRadius.lg,
    bool glow = false,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      color: color ?? AppColors.glassFillStrong,
      border: Border.all(color: AppColors.glassBorder, width: 0.75),
      boxShadow: glow
          ? [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.14),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ]
          : [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
    );
  }

  /// Feature surface (hero / report header) — warm wine wash on linen.
  static BoxDecoration heroCard() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.primary.withValues(alpha: 0.18),
          AppColors.glassFillStrong,
          AppColors.primaryDim.withValues(alpha: 0.10),
        ],
      ),
      border: Border.all(
        color: AppColors.primary.withValues(alpha: 0.24),
      ),
    );
  }

  static BoxDecoration iconButton() {
    return BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.surfaceHigh,
      border: Border.all(color: AppColors.glassBorder),
    );
  }

  static BoxDecoration monthSelector() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      color: AppColors.surfaceHigh,
      border: Border.all(color: AppColors.glassBorder),
    );
  }
}
