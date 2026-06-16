import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// HISAAB brand mark — transparent PNG, tinted white by default and
/// recolourable via [color] / [emphasized].
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({
    super.key,
    this.size = 22,
    this.color,
    this.opacity = 1,
    this.emphasized = false,
  });

  final double size;
  final Color? color;
  final double opacity;
  final bool emphasized;

  static const _assetPath = 'assets/images/logo.png';

  @override
  Widget build(BuildContext context) {
    final tint = color ??
        (emphasized ? AppColors.brand : AppColors.textPrimary);

    Widget child = Image.asset(
      _assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => _FallbackMark(
        size: size,
        color: tint.withValues(alpha: opacity),
      ),
    );

    child = ColorFiltered(
      colorFilter: ColorFilter.mode(
        tint.withValues(alpha: opacity),
        BlendMode.srcIn,
      ),
      child: child,
    );

    return SizedBox(width: size, height: size, child: child);
  }
}

/// Vector fallback if the asset fails to load.
class _FallbackMark extends StatelessWidget {
  const _FallbackMark({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _HLogoPainter(color: color),
    );
  }
}

class _HLogoPainter extends CustomPainter {
  const _HLogoPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;
    canvas.drawPath(_buildPath(size.width, size.height), paint);
  }

  static Path _buildPath(double w, double h) {
    double x(double v) => v / 100 * w;
    double y(double v) => v / 100 * h;

    final path = Path();

    path.moveTo(x(16), y(20));
    path.lineTo(x(24), y(12));
    path.lineTo(x(32), y(12));
    path.lineTo(x(32), y(88));
    path.lineTo(x(16), y(88));
    path.close();

    path.moveTo(x(68), y(12));
    path.lineTo(x(84), y(12));
    path.lineTo(x(84), y(80));
    path.lineTo(x(76), y(88));
    path.lineTo(x(68), y(88));
    path.close();

    path.moveTo(x(32), y(40));
    path.lineTo(x(68), y(48));
    path.lineTo(x(68), y(60));
    path.lineTo(x(32), y(52));
    path.close();

    return path;
  }

  @override
  bool shouldRepaint(_HLogoPainter oldDelegate) => oldDelegate.color != color;
}
