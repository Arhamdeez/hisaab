import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// Frosted linen glass — light blur, warm translucency, soft edges.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.radius = 24,
    this.padding,
    this.margin,
    this.blur = 10,
    this.tint,
    this.enableBlur = true,
    this.borderWidth = 0.75,
    this.showShadow = true,
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

  @override
  Widget build(BuildContext context) {
    final fill = tint ?? AppColors.glassFill;
    final br = BorderRadius.circular(radius);

    Widget body = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.glassHighlight.withValues(alpha: 0.14),
            fill,
            AppColors.primary.withValues(alpha: 0.04),
          ],
          stops: const [0.0, 0.45, 1.0],
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
                height: (radius * 0.55).clamp(12.0, 28.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(radius),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.16),
                      Colors.white.withValues(alpha: 0.0),
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

    body = ClipRRect(
      borderRadius: br,
      child: enableBlur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: body,
            )
          : body,
    );

    Widget surface = showShadow
        ? DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: br,
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: body,
          )
        : body;

    if (margin != null) {
      return Padding(padding: margin!, child: surface);
    }
    return surface;
  }
}

/// Glass list/card surface — use instead of opaque [AppDecorations.card].
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = AppRadius.lg,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      radius: radius,
      enableBlur: false,
      padding: padding,
      margin: margin,
      child: child,
    );
  }
}

/// Dark Vintage Hearth ambience — deep red-black base with wine glow washes
/// so glass layers have warm colour to refract.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.gradientStart,
              AppColors.gradientMid,
              AppColors.gradientEnd,
            ],
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            Align(
              alignment: const Alignment(0.75, -1.05),
              child: _GlowOrb(
                size: 440,
                color: AppColors.primary.withValues(alpha: 0.42),
                blur: 95,
              ),
            ),
            Align(
              alignment: const Alignment(-0.85, -0.4),
              child: _GlowOrb(
                size: 360,
                color: AppColors.glowWine.withValues(alpha: 0.6),
                blur: 90,
              ),
            ),
            Align(
              alignment: const Alignment(0.9, 0.5),
              child: _GlowOrb(
                size: 320,
                color: AppColors.glowMaroon.withValues(alpha: 0.45),
                blur: 100,
              ),
            ),
            Align(
              alignment: const Alignment(-0.55, 1.05),
              child: _GlowOrb(
                size: 380,
                color: AppColors.primaryDim.withValues(alpha: 0.4),
                blur: 95,
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.1),
                  radius: 1.15,
                  colors: [
                    AppColors.background.withValues(alpha: 0.0),
                    AppColors.background.withValues(alpha: 0.4),
                  ],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.color,
    this.blur = 60,
  });

  final double size;
  final Color color;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}
