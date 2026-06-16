import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

abstract final class AppDecorations {
  /// Standard surface — quiet fill, hairline border, one soft shadow.
  /// Deliberately restrained so stacked cards don't feel noisy.
  static BoxDecoration card({
    Color? color,
    double radius = AppRadius.lg,
    bool glow = false,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      color: color ?? AppColors.glassFill,
      border: Border.all(color: AppColors.glassBorder, width: 0.75),
      boxShadow: glow
          ? [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ]
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
    );
  }

  /// Feature surface (hero / report header) — a faint warm wash + accent edge.
  static BoxDecoration heroCard() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.primary.withValues(alpha: 0.10),
          AppColors.glassFillStrong,
        ],
      ),
      border: Border.all(
        color: AppColors.primary.withValues(alpha: 0.18),
      ),
    );
  }

  static BoxDecoration iconButton() {
    return BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.surface,
      border: Border.all(color: AppColors.glassBorder),
    );
  }

  static BoxDecoration monthSelector() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      color: AppColors.surface,
      border: Border.all(color: AppColors.glassBorder),
    );
  }
}
