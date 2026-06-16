import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../../widgets/app_logo_mark.dart';
import '../../features/ingest/ingest_service.dart';
import '../../providers/transaction_provider.dart';

/// Bouncing physics so the overscroll distance drives the refresh visual,
/// and so pull-to-refresh works even when content is shorter than the viewport.
const refreshScrollPhysics = AlwaysScrollableScrollPhysics(
  parent: BouncingScrollPhysics(),
);

/// Syncs Gmail if connected, then refreshes local data.
Future<void> refreshAppData(BuildContext context) async {
  final provider = context.read<TransactionProvider>();
  final ingest = context.read<IngestService>();

  final started = DateTime.now();
  if (ingest.isGmailConnected) {
    await ingest.syncGmail();
  }
  await provider.reload();

  // Keep the skeleton visible long enough to read as a deliberate refresh.
  const minVisible = Duration(milliseconds: 900);
  final elapsed = DateTime.now().difference(started);
  if (elapsed < minVisible) {
    await Future.delayed(minVisible - elapsed);
  }
}

/// Premium pull-to-refresh.
///
/// The visual is driven by the live overscroll distance (computed by the
/// physics engine), so the orb tracks the finger 1:1 and rides the elastic
/// bounce-back — no custom scroll math fighting the view, no discrete snapping.
/// Only the small orb repaints during a pull (it lives in a [RepaintBoundary]).
class AppRefreshIndicator extends StatefulWidget {
  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.skeleton,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final Widget? skeleton;

  @override
  State<AppRefreshIndicator> createState() => _AppRefreshIndicatorState();
}

class _AppRefreshIndicatorState extends State<AppRefreshIndicator>
    with TickerProviderStateMixin {
  /// Overscroll distance (px) needed to arm a refresh.
  static const _trigger = 86.0;

  /// Where the orb rests while the refresh callback runs.
  static const _holdExtent = 60.0;

  /// Live pull distance in logical pixels (0 = at rest).
  final _pull = ValueNotifier<double>(0);
  final _refreshing = ValueNotifier<bool>(false);

  /// Drives the smooth crossfade between content and skeleton (0..1).
  late final AnimationController _fade;

  late final AnimationController _spin;
  AnimationController? _settle;
  double _settleFrom = 0;
  double _settleTo = 0;

  bool _armed = false;
  bool _inFlight = false;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void reassemble() {
    super.reassemble();
    // Recover cleanly across hot reloads.
    _settle?.dispose();
    _settle = null;
    _spin.stop();
    _spin.reset();
    _fade.value = 0;
    _pull.value = 0;
    _refreshing.value = false;
    _armed = false;
    _inFlight = false;
  }

  @override
  void dispose() {
    _pull.dispose();
    _refreshing.dispose();
    _spin.dispose();
    _fade.dispose();
    _settle?.dispose();
    super.dispose();
  }

  void _onSettleTick() {
    final settle = _settle;
    if (settle == null) return;
    final t = Curves.easeOutCubic.transform(settle.value);
    _pull.value = _settleFrom + (_settleTo - _settleFrom) * t;
  }

  Future<void> _animatePullTo(double target, {int ms = 260}) {
    _settle?.dispose();
    final controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: ms),
    )..addListener(_onSettleTick);
    _settle = controller;
    _settleFrom = _pull.value;
    _settleTo = target;
    return controller.forward().orCancel.catchError((_) {});
  }

  bool _handleScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    if (_inFlight) return false;

    // With bouncing physics, pixels go negative when overscrolled at the top.
    final overscroll = n.metrics.pixels < 0 ? -n.metrics.pixels : 0.0;
    _pull.value = overscroll;

    final armedNow = overscroll >= _trigger;
    if (armedNow && !_armed) {
      _armed = true;
      HapticFeedback.lightImpact();
    } else if (!armedNow && _armed) {
      _armed = false;
    }

    // Finger lifted: try multiple notification types — Android doesn't always
    // emit UserScrollNotification.idle during a pull-to-refresh overscroll.
    final shouldStart = _armed &&
        (n is UserScrollNotification && n.direction == ScrollDirection.idle ||
            n is ScrollEndNotification);
    if (shouldStart) {
      _startRefresh();
    }

    return false;
  }

  Future<void> _startRefresh() async {
    if (_inFlight) return;
    _inFlight = true;
    _armed = false;
    _refreshing.value = true;

    HapticFeedback.mediumImpact();
    _spin.repeat();
    // Smoothly crossfade content -> skeleton as the orb settles into its hold.
    _fade.forward();
    await _animatePullTo(_holdExtent, ms: 240);

    try {
      await widget.onRefresh();
    } catch (_) {}

    if (!mounted) {
      _inFlight = false;
      return;
    }

    _spin.stop();
    _spin.reset();
    await _animatePullTo(0, ms: 320);

    // Gently fade the skeleton back out, then drop the refreshing flag once
    // the content is fully visible again so nothing pops.
    await _fade.reverse();
    _refreshing.value = false;
    _inFlight = false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScroll,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _fade,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(_fade.value);
              return Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: 1 - t * 0.86,
                    child: child,
                  ),
                  if (t > 0 && widget.skeleton != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: t,
                          child: ColoredBox(
                            color: AppColors.background
                                .withValues(alpha: 0.55 * t),
                            child: widget.skeleton,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
            child: widget.child,
          ),
          _RefreshOverlay(
            pull: _pull,
            refreshing: _refreshing,
            spin: _spin,
            trigger: _trigger,
          ),
        ],
      ),
    );
  }
}

class _RefreshOverlay extends StatelessWidget {
  const _RefreshOverlay({
    required this.pull,
    required this.refreshing,
    required this.spin,
    required this.trigger,
  });

  final ValueNotifier<double> pull;
  final ValueNotifier<bool> refreshing;
  final AnimationController spin;
  final double trigger;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return ValueListenableBuilder<bool>(
      valueListenable: refreshing,
      builder: (context, isRefreshing, _) {
        return ValueListenableBuilder<double>(
          valueListenable: pull,
          builder: (context, pullpx, _) {
            if (pullpx <= 0.5 && !isRefreshing) {
              return const SizedBox.shrink();
            }

            final progress = (pullpx / trigger).clamp(0.0, 1.0);
            final armed = pullpx >= trigger;

            // Orb follows the pull, easing toward a fixed resting offset.
            final travel = math.min(pullpx, trigger);
            final top = topInset + 8 + travel * 0.55;

            return Positioned(
              top: top,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: _RefreshOrb(
                    progress: progress,
                    spin: spin,
                    refreshing: isRefreshing,
                    armed: armed,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _RefreshOrb extends StatelessWidget {
  const _RefreshOrb({
    required this.progress,
    required this.spin,
    required this.refreshing,
    required this.armed,
  });

  final double progress;
  final AnimationController spin;
  final bool refreshing;
  final bool armed;

  @override
  Widget build(BuildContext context) {
    final eased = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final scale = refreshing ? 1.0 : 0.7 + eased * 0.3;
    final opacity = refreshing ? 1.0 : Curves.easeOut.transform(progress);

    return Center(
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _OrbBackdrop(active: armed || refreshing),
                if (refreshing)
                  RotationTransition(
                    turns: spin,
                    child: CustomPaint(
                      size: const Size(38, 38),
                      painter: _SpinRingPainter(),
                    ),
                  )
                else
                  CustomPaint(
                    size: const Size(38, 38),
                    painter: _PullRingPainter(
                      progress: progress,
                      armed: armed,
                    ),
                  ),
                AppLogoMark(
                  size: 18,
                  emphasized: armed || refreshing,
                  opacity: refreshing ? 1 : 0.6 + progress * 0.4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbBackdrop extends StatelessWidget {
  const _OrbBackdrop({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.glassHighlight.withValues(alpha: 0.6),
            AppColors.glassFillStrong,
          ],
        ),
        border: Border.all(
          color: active
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.glassBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: active
                ? AppColors.primary.withValues(alpha: 0.24)
                : AppColors.shadow,
            blurRadius: active ? 18 : 12,
            spreadRadius: active ? -2 : -4,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );
  }
}

class _PullRingPainter extends CustomPainter {
  _PullRingPainter({required this.progress, required this.armed});

  final double progress;
  final bool armed;

  static final _track = Paint()
    ..color = AppColors.surfaceMuted
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round;

  static final _arc = Paint()
    ..color = AppColors.primary
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round;

  static final _arcArmed = Paint()
    ..color = AppColors.primaryGlow
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(center, radius, _track);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      progress * math.pi * 2,
      false,
      armed ? _arcArmed : _arc,
    );
  }

  @override
  bool shouldRepaint(_PullRingPainter old) =>
      old.progress != progress || old.armed != armed;
}

class _SpinRingPainter extends CustomPainter {
  static final _arc = Paint()
    ..shader = const SweepGradient(
      colors: [
        Color(0x006F1D1B),
        AppColors.primary,
        AppColors.primaryGlow,
      ],
      stops: [0.0, 0.7, 1.0],
    ).createShader(const Rect.fromLTWH(0, 0, 38, 38))
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, 0, math.pi * 1.45, false, _arc);
  }

  @override
  bool shouldRepaint(_SpinRingPainter old) => false;
}

/// Pull-to-refresh with an optional shimmer [skeleton] overlay while loading.
class AppRefreshScroll extends StatelessWidget {
  const AppRefreshScroll({
    super.key,
    required this.child,
    required this.skeleton,
  });

  final Widget child;
  final Widget skeleton;

  @override
  Widget build(BuildContext context) {
    return AppRefreshIndicator(
      skeleton: skeleton,
      onRefresh: () => refreshAppData(context),
      child: child,
    );
  }
}
