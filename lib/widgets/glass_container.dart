import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// iOS-style liquid glass — light blur, high translucency, luminous edges.
/// Less "frosted milk", more see-through vibrancy.
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
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final Color? tint;
  final bool enableBlur;
  final double borderWidth;

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
            AppColors.glassHighlight.withValues(alpha: 0.10),
            fill,
            Colors.white.withValues(alpha: 0.02),
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
          // Thin luminous rim — iOS glass catches light along the top edge.
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
                      Colors.white.withValues(alpha: 0.14),
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

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: body,
    );

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
    // No live backdrop blur: these surfaces are used inside scrolling lists
    // (and repeated many times), where stacked BackdropFilters cause jank.
    // The glass look is carried by translucency + luminous edges instead.
    return GlassContainer(
      radius: radius,
      enableBlur: false,
      padding: padding,
      margin: margin,
      child: child,
    );
  }
}

/// Quiet, warm ambient backdrop so glass layers have colour to refract.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary isolates this static, blur-heavy backdrop into its own
    // cached layer so it is painted once — not re-rendered every scroll frame.
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: const BoxDecoration(color: AppColors.background),
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            // Saturated colour blobs so glass surfaces have colour to refract.
            Align(
              alignment: const Alignment(0.7, -1.05),
              child: _GlowOrb(
                size: 420,
                color: AppColors.primary.withValues(alpha: 0.45),
                blur: 90,
              ),
            ),
            Align(
              alignment: const Alignment(-0.85, -0.45),
              child: _GlowOrb(
                size: 320,
                color: AppColors.glowWine.withValues(alpha: 0.7),
                blur: 85,
              ),
            ),
            Align(
              alignment: const Alignment(0.9, 0.5),
              child: _GlowOrb(
                size: 300,
                color: AppColors.saved.withValues(alpha: 0.22),
                blur: 95,
              ),
            ),
            Align(
              alignment: const Alignment(-0.6, 1.05),
              child: _GlowOrb(
                size: 340,
                color: AppColors.primaryDim.withValues(alpha: 0.4),
                blur: 95,
              ),
            ),
            // Hold the centre slightly darker so foreground text stays legible.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.1),
                  radius: 1.1,
                  colors: [
                    AppColors.background.withValues(alpha: 0.0),
                    AppColors.background.withValues(alpha: 0.35),
                  ],
                  stops: const [0.55, 1.0],
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
