import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_decorations.dart';
import '../core/theme/app_spacing.dart';

/// iOS-style frosted glass — backdrop blur, translucent tint, specular edge.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.radius = AppRadius.xl,
    this.padding,
    this.margin,
    this.blur = 14,
    this.tint,
    this.enableBlur = true,
    this.borderWidth = 0.85,
    this.showShadow = true,
    this.accentGlow = false,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final Color? tint;
  final bool enableBlur;
  final double borderWidth;
  final bool showShadow;
  final bool accentGlow;

  @override
  Widget build(BuildContext context) {
    final fill = tint ?? AppColors.glassFill;
    final br = BorderRadius.circular(radius);
    final specularH = (radius * 0.5).clamp(10.0, 24.0);

    Widget panel = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.glassHighlight,
            fill,
            AppColors.glassFillDeep,
            AppColors.glassFillStrong,
          ],
          stops: const [0.0, 0.25, 0.65, 1.0],
        ),
        border: Border.all(
          color: AppColors.glassBorder,
          width: borderWidth,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: specularH,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(radius),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.glassSpecular,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (padding != null)
            Padding(padding: padding!, child: child)
          else
            child,
        ],
      ),
    );

    panel = ClipRRect(
      borderRadius: br,
      child: enableBlur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: panel,
            )
          : panel,
    );

    Widget surface = showShadow || accentGlow
        ? DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: br,
              boxShadow: [
                if (showShadow) ...[
                  BoxShadow(
                    color: AppColors.shadow.withValues(alpha: 0.55),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
                if (accentGlow) ...AppDecorations.heroGlow(),
                if (showShadow && !accentGlow)
                  BoxShadow(
                    color: AppColors.ui.withValues(alpha: 0.06),
                    blurRadius: 32,
                    spreadRadius: -8,
                    offset: const Offset(0, 12),
                  ),
              ],
            ),
            child: panel,
          )
        : panel;

    surface = RepaintBoundary(child: surface);

    if (margin != null) {
      return Padding(padding: margin!, child: surface);
    }
    return surface;
  }
}

/// Glass list/card surface.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = AppRadius.lg,
    this.accentGlow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final bool accentGlow;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      radius: radius,
      blur: 10,
      tint: AppColors.glassFillStrong,
      accentGlow: accentGlow,
      padding: padding,
      margin: margin,
      child: child,
    );
  }
}

/// Pure black canvas — optional subtle grey lift for glass depth.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: ColoredBox(color: AppColors.background),
    );
  }
}
