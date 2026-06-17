import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/splash_timing.dart';
import '../core/theme/app_colors.dart';
import '../widgets/app_logo_mark.dart';

/// Black native splash → logo fades in → brief hold → drop → bubble reveals [child].
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

enum _SplashPhase { enter, hold, drop, pause, bubble, done }

class _SplashGateState extends State<SplashGate> with TickerProviderStateMixin {
  static const _logoSize = SplashTiming.logoSize;
  static const _dropDuration = Duration(milliseconds: 580);
  static const _bubbleDuration = Duration(milliseconds: 1200);
  static const _pauseAfterDrop = Duration(milliseconds: 60);

  late final AnimationController _enter;
  late final AnimationController _drop;
  late final AnimationController _bubble;

  late final Animation<double> _enterOpacity;
  late final Animation<double> _enterScale;
  late final Animation<double> _enterLift;
  late final Animation<double> _dropTravel;
  late final Animation<double> _dropOpacity;
  late final Animation<double> _bubbleExpand;

  _SplashPhase _phase = _SplashPhase.enter;
  bool _introDone = false;
  bool _pendingExit = false;
  bool _finished = false;
  bool _sequenceStarted = false;

  Size? _cachedSize;
  late Offset _bubbleOrigin;
  late double _maxBubbleRadius;
  late double _exitDistance;

  @override
  void initState() {
    super.initState();

    _enter = AnimationController(
      vsync: this,
      duration: SplashTiming.enterFade,
    );
    _enterOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _enter,
        curve: Curves.easeInOutCubic,
      ),
    );
    _enterScale = Tween<double>(begin: 0.94, end: 1).animate(
      CurvedAnimation(
        parent: _enter,
        curve: const Interval(0.12, 1, curve: Curves.easeOutCubic),
      ),
    );
    _enterLift = Tween<double>(begin: 10, end: 0).animate(
      CurvedAnimation(
        parent: _enter,
        curve: const Interval(0.08, 1, curve: Curves.easeOutCubic),
      ),
    );

    _drop = AnimationController(vsync: this, duration: _dropDuration);
    _dropTravel = CurvedAnimation(
      parent: _drop,
      curve: Curves.easeInCubic,
    );
    _dropOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _drop,
        curve: const Interval(0.8, 1.0, curve: Curves.easeOut),
      ),
    );

    _bubble = AnimationController(vsync: this, duration: _bubbleDuration);
    _bubbleExpand = CurvedAnimation(
      parent: _bubble,
      curve: const _SmoothBubbleCurve(),
    );

    _drop.addStatusListener(_onDropStatus);
    _bubble.addStatusListener(_onBubbleStatus);
    _bubble.addListener(_checkBubbleComplete);

    WidgetsBinding.instance.addPostFrameCallback((_) => _runSequence());
  }

  Future<void> _runSequence() async {
    if (!mounted || _sequenceStarted) return;
    _sequenceStarted = true;

    setState(() => _phase = _SplashPhase.enter);
    await Future<void>.delayed(SplashTiming.enterDelay);
    if (!mounted) return;

    await _enter.forward(from: 0).orCancel.catchError((_) {});
    if (!mounted) return;

    setState(() => _phase = _SplashPhase.hold);
    await Future<void>.delayed(SplashTiming.introHold);
    if (!mounted || _phase != _SplashPhase.hold) return;

    _introDone = true;
    if (widget.ready || _pendingExit) {
      _startDrop();
    }
  }

  void _checkBubbleComplete() {
    if (_phase != _SplashPhase.bubble || _finished) return;
    if (_bubbleExpand.value >= 0.995) {
      _finish();
    }
  }

  void _onDropStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _phase != _SplashPhase.drop) {
      return;
    }
    setState(() => _phase = _SplashPhase.pause);
    Future<void>.delayed(_pauseAfterDrop, () {
      if (!mounted || _phase != _SplashPhase.pause) return;
      setState(() => _phase = _SplashPhase.bubble);
      _bubble.forward(from: 0);
    });
  }

  void _onBubbleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        _phase == _SplashPhase.bubble &&
        !_finished) {
      _finish();
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onFinished();
  }

  void _startDrop() {
    if (_phase != _SplashPhase.hold) return;
    setState(() => _phase = _SplashPhase.drop);
    _drop.forward(from: 0);
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
    _exitDistance = size.height / 2 + _logoSize / 2 + 72;
  }

  @override
  void didUpdateWidget(SplashGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ready && !oldWidget.ready) {
      if (_introDone) {
        _startDrop();
      } else {
        _pendingExit = true;
      }
    }
  }

  @override
  void dispose() {
    _drop.removeStatusListener(_onDropStatus);
    _bubble.removeStatusListener(_onBubbleStatus);
    _bubble.removeListener(_checkBubbleComplete);
    _enter.dispose();
    _drop.dispose();
    _bubble.dispose();
    super.dispose();
  }

  double _snapRadius(double radius) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return (radius * dpr).round() / dpr;
  }

  bool get _showLogo =>
      _phase == _SplashPhase.enter ||
      _phase == _SplashPhase.hold ||
      _phase == _SplashPhase.drop;

  bool get _showOverlay => _phase != _SplashPhase.done;

  @override
  Widget build(BuildContext context) {
    _cacheLayoutMetrics(MediaQuery.sizeOf(context));
    final size = _cachedSize ?? MediaQuery.sizeOf(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.ready)
          RepaintBoundary(child: widget.child)
        else
          const ColoredBox(color: AppColors.background),
        if (_showOverlay)
          RepaintBoundary(
            child: _phase == _SplashPhase.bubble
                ? AnimatedBuilder(
                    animation: _bubble,
                    builder: (context, _) {
                      final bubbleT = _bubbleExpand.value;
                      final radius = bubbleT > 0
                          ? _snapRadius(_maxBubbleRadius * bubbleT)
                          : 0.0;
                      return CustomPaint(
                        painter: _SplashMaskPainter(
                          center: _bubbleOrigin,
                          radius: radius,
                          bubbleT: bubbleT,
                          fullCover: bubbleT <= 0,
                        ),
                        size: size,
                      );
                    },
                  )
                : CustomPaint(
                    painter: _SplashMaskPainter(
                      center: _bubbleOrigin,
                      radius: 0,
                      bubbleT: 0,
                      fullCover: true,
                    ),
                    size: size,
                  ),
          ),
        if (_showLogo) RepaintBoundary(child: _buildLogo()),
      ],
    );
  }

  Widget _buildLogo() {
    const logo = _SplashLogo();

    if (_phase == _SplashPhase.drop) {
      return AnimatedBuilder(
        animation: _drop,
        builder: (context, child) {
          return Center(
            child: Transform.translate(
              offset: Offset(0, _exitDistance * _dropTravel.value),
              child: Opacity(
                opacity: _dropOpacity.value.clamp(0.0, 1.0),
                child: child,
              ),
            ),
          );
        },
        child: logo,
      );
    }

    if (_phase == _SplashPhase.enter) {
      return AnimatedBuilder(
        animation: _enter,
        builder: (context, child) {
          return Center(
            child: Transform.translate(
              offset: Offset(0, _enterLift.value),
              child: Opacity(
                opacity: _enterOpacity.value.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: _enterScale.value,
                  child: child,
                ),
              ),
            ),
          );
        },
        child: logo,
      );
    }

    return const Center(child: logo);
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
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    const size = _SplashGateState._logoSize;
    return SizedBox(
      width: size,
      height: size,
      child: const AppLogoMark(size: size, emphasized: true),
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
