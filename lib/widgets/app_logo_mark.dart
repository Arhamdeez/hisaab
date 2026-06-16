import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// HISAAB brand mark — a geometric "H" monogram: two angled pillars joined by
/// a bold diagonal, with two triangular negative-space notches.
///
/// Drawn as a vector so it stays razor-sharp at any size and can be tinted to
/// any colour (solid via [color], or with a gradient via a [ShaderMask] wrapper
/// as used on the splash screen).
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

  @override
  Widget build(BuildContext context) {
    final resolved =
        (color ?? (emphasized ? AppColors.primary : AppColors.textPrimary))
            .withValues(alpha: opacity);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HLogoPainter(color: resolved),
      ),
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
    canvas.drawPath(buildPath(size.width, size.height), paint);
  }

  /// Builds the monogram on a 100×100 design grid scaled to [w]×[h].
  static Path buildPath(double w, double h) {
    double x(double v) => v / 100 * w;
    double y(double v) => v / 100 * h;

    final path = Path();

    // Left pillar — chamfered top-left corner.
    path.moveTo(x(16), y(20));
    path.lineTo(x(24), y(12));
    path.lineTo(x(32), y(12));
    path.lineTo(x(32), y(88));
    path.lineTo(x(16), y(88));
    path.close();

    // Right pillar — chamfered bottom-right corner (point-symmetric).
    path.moveTo(x(68), y(12));
    path.lineTo(x(84), y(12));
    path.lineTo(x(84), y(80));
    path.lineTo(x(76), y(88));
    path.lineTo(x(68), y(88));
    path.close();

    // Crossbar joining the pillars — centred and near-horizontal (with a
    // slight downward slope to the right) so it reads clearly as an "H".
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
