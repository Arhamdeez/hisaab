import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../widgets/app_logo_mark.dart';

/// Launch: logo appears → drops off-screen → bubble opens to reveal [child].
class SplashGate extends StatefulWidget {
  const SplashGate({
    super.key,
    required this.ready,
    required this.child,
    required this.onFinished,
  });

  final bool ready;
  final Widget child;
  final VoidCallback onFinished;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> with SingleTickerProviderStateMixin {
  static const _appearEndT = 0.22;
  static const _introHold = Duration(milliseconds: 800);
  static const _logoSize = 88.0;

  late final AnimationController _c;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoExit;
  late final Animation<double> _bubbleExpand;

  bool _exitStarted = false;
  bool _introDone = false;
  bool _pendingExit = false;
  bool _finished = false;

  // Cached layout — avoids recomputing trig every frame.
  Size? _cachedSize;
  late Offset _bubbleOrigin;
  late double _maxBubbleRadius;
  late double _exitDistance;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    _logoOpacity = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.0, 0.22, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.48, end: 1.0).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.0, 0.26, curve: Curves.easeOutBack),
      ),
    );

    _logoExit = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.22, 0.38, curve: Curves.easeInQuart),
    );

    _bubbleExpand = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.44, 1.0, curve: _SmoothBubbleCurve()),
    );

    _c.addStatusListener(_onTick);
    _c.addListener(_checkBubbleComplete);
    WidgetsBinding.instance.addPostFrameCallback((_) => _playIntro());
  }

  void _checkBubbleComplete() {
    if (_exitStarted &&
        !_finished &&
        _bubbleExpand.value >= 0.995) {
      _finished = true;
      widget.onFinished();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cacheLayoutMetrics(MediaQuery.sizeOf(context));
  }

  void _cacheLayoutMetrics(Size size) {
    if (_cachedSize == size) return;
    _cachedSize = size;
    _bubbleOrigin = Offset(size.width / 2, size.height + 6);
    final cx = size.width / 2;
    _maxBubbleRadius = math.sqrt(cx * cx + size.height * size.height) + 48;
    _exitDistance = size.height / 2 + _logoSize / 2 + 64;
  }

  Future<void> _playIntro() async {
    if (!mounted || _exitStarted) return;
    await _c.animateTo(
      _appearEndT,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
    );
    if (!mounted || _exitStarted) return;
    await Future<void>.delayed(_introHold);
    if (!mounted || _exitStarted) return;
    _introDone = true;
    if (widget.ready || _pendingExit) _startExit();
  }

  void _startExit() {
    if (_exitStarted) return;
    _exitStarted = true;
    _c.forward();
  }

  void _onTick(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        _exitStarted &&
        !_finished) {
      _finished = true;
      widget.onFinished();
    }
  }

  @override
  void didUpdateWidget(SplashGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ready && !oldWidget.ready) {
      if (_introDone) {
        _startExit();
      } else {
        _pendingExit = true;
      }
    }
  }

  @override
  void dispose() {
    _c.removeListener(_checkBubbleComplete);
    _c.removeStatusListener(_onTick);
    _c.dispose();
    super.dispose();
  }

  double _snapRadius(double radius) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return (radius * dpr).round() / dpr;
  }

  @override
  Widget build(BuildContext context) {
    _cacheLayoutMetrics(MediaQuery.sizeOf(context));

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final bubbleT = _bubbleExpand.value;
        final exitT = _logoExit.value;
        final bubbleRadius = bubbleT > 0
            ? _snapRadius(_maxBubbleRadius * bubbleT)
            : 0.0;

        final logoVisible =
            _logoOpacity.value > 0.01 && exitT < 1.0 && bubbleT <= 0;
        final exitFade = exitT < 0.82
            ? 1.0
            : (1 - (exitT - 0.82) / 0.18).clamp(0.0, 1.0);
        final logoScale = _logoScale.value * (1 - exitT * 0.06);

        final showOverlay =
            !_exitStarted || bubbleT < 0.999;

        return Stack(
          fit: StackFit.expand,
          children: [
            if (widget.ready)
              RepaintBoundary(child: widget.child)
            else
              const ColoredBox(color: AppColors.background),
            if (showOverlay)
              RepaintBoundary(
                child: CustomPaint(
                  painter: _SplashMaskPainter(
                    center: _bubbleOrigin,
                    radius: bubbleRadius,
                    bubbleT: bubbleT,
                    fullCover: !_exitStarted || bubbleT <= 0,
                  ),
                  size: _cachedSize ?? MediaQuery.sizeOf(context),
                ),
              ),
            if (logoVisible)
              RepaintBoundary(
                child: Center(
                  child: Transform.translate(
                    offset: Offset(0, _exitDistance * exitT),
                    child: Opacity(
                      opacity:
                          (_logoOpacity.value * exitFade).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: logoScale,
                        child: _SplashLogo(showHalo: exitT < 0.06),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One painter for mask + ring — avoids ClipPath compositing jank.
class _SplashMaskPainter extends CustomPainter {
  _SplashMaskPainter({
    required this.center,
    required this.radius,
    required this.bubbleT,
    required this.fullCover,
  });

  final Offset center;
  final double radius;
  final double bubbleT;
  final bool fullCover;

  static final _fillPaint = Paint()..color = AppColors.background;

  @override
  void paint(Canvas canvas, Size size) {
    if (fullCover || radius <= 0) {
      canvas.drawRect(Offset.zero & size, _fillPaint);
      return;
    }

    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.drawPath(mask, _fillPaint);

    if (radius < 4 || bubbleT <= 0) return;

    final edgeOpacity =
        (1 - math.pow(bubbleT, 2.2).toDouble()).clamp(0.0, 1.0);
    if (edgeOpacity <= 0.01) return;

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..color = AppColors.brand.withValues(alpha: 0.28 * edgeOpacity);
    canvas.drawCircle(center, radius, glow);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = AppColors.brandGlow.withValues(alpha: 0.95 * edgeOpacity);
    canvas.drawCircle(center, radius, ring);

    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AppColors.brand.withValues(alpha: 0.5 * edgeOpacity);
    canvas.drawCircle(center, radius - 2, inner);
  }

  @override
  bool shouldRepaint(covariant _SplashMaskPainter old) =>
      old.radius != radius ||
      old.bubbleT != bubbleT ||
      old.fullCover != fullCover ||
      old.center != center;
}

class _SmoothBubbleCurve extends Curve {
  const _SmoothBubbleCurve();

  @override
  double transformInternal(double t) {
    final inv = 1 - t;
    return 1 - inv * inv * inv * inv * inv;
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo({required this.showHalo});

  final bool showHalo;

  @override
  Widget build(BuildContext context) {
    const size = _SplashGateState._logoSize;
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (showHalo)
              Container(
                width: size * 1.4,
                height: size * 1.4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.brand.withValues(alpha: 0.14),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            const AppLogoMark(size: size, emphasized: true),
          ],
        ),
      ),
    );
  }
}

/// Legacy entry — prefer [SplashGate].
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return SplashGate(
      ready: true,
      onFinished: onComplete,
      child: const SizedBox.shrink(),
    );
  }
}
