import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../splash_timing.dart';
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

  // Keep the logo on screen long enough to read as a deliberate refresh.
  const minVisible = Duration(milliseconds: 700);
  final elapsed = DateTime.now().difference(started);
  if (elapsed < minVisible) {
    await Future.delayed(minVisible - elapsed);
  }
}

/// Premium pull-to-refresh.
///
/// Pull reveals a small orb; on release the screen blacks out, the logo
/// animates in, data reloads, then the app fades back in.
class AppRefreshIndicator extends StatefulWidget {
  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.orbTopOffset = 0,
    this.orbMinPull = 0.5,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  /// Nudge orb vertically after layout (negative = slightly higher).
  final double orbTopOffset;

  /// Minimum pull distance before the orb appears.
  final double orbMinPull;

  @override
  State<AppRefreshIndicator> createState() => _AppRefreshIndicatorState();
}

class _AppRefreshIndicatorState extends State<AppRefreshIndicator>
    with TickerProviderStateMixin {
  static const _trigger = 86.0;

  final _pull = ValueNotifier<double>(0);
  final _refreshing = ValueNotifier<bool>(false);

  late final AnimationController _cover;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;

  AnimationController? _settle;
  double _settleFrom = 0;
  double _settleTo = 0;

  bool _armed = false;
  bool _inFlight = false;

  @override
  void initState() {
    super.initState();
    _cover = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _logoOpacity = CurvedAnimation(
      parent: _cover,
      curve: const Interval(0.06, 0.58, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.52, end: 1.0).animate(
      CurvedAnimation(
        parent: _cover,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
      ),
    );
  }

  @override
  void reassemble() {
    super.reassemble();
    _settle?.dispose();
    _settle = null;
    _cover.value = 0;
    _pull.value = 0;
    _refreshing.value = false;
    _armed = false;
    _inFlight = false;
  }

  @override
  void dispose() {
    _pull.dispose();
    _refreshing.dispose();
    _cover.dispose();
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

    final overscroll = n.metrics.pixels < 0 ? -n.metrics.pixels : 0.0;
    _pull.value = overscroll;

    final armedNow = overscroll >= _trigger;
    if (armedNow && !_armed) {
      _armed = true;
      HapticFeedback.lightImpact();
    } else if (!armedNow && _armed) {
      _armed = false;
    }

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
    await _animatePullTo(0, ms: 200);

    if (!mounted) {
      _inFlight = false;
      return;
    }

    await _cover.forward().orCancel.catchError((_) {});

    try {
      await widget.onRefresh();
    } catch (_) {}

    if (!mounted) {
      _inFlight = false;
      return;
    }

    await _cover.reverse().orCancel.catchError((_) {});
    _refreshing.value = false;
    _inFlight = false;
  }

  @override
  void deactivate() {
    _resetRefreshVisuals();
    super.deactivate();
  }

  void _resetRefreshVisuals() {
    _settle?.dispose();
    _settle = null;
    _cover.stop();
    _cover.value = 0;
    _pull.value = 0;
    _refreshing.value = false;
    _armed = false;
    _inFlight = false;
  }

  @override
  Widget build(BuildContext context) {
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    if (!tickerEnabled && (_cover.value > 0 || _inFlight)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || TickerMode.valuesOf(context).enabled) return;
        _resetRefreshVisuals();
      });
    }

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScroll,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          widget.child,
          if (_cover.isAnimating || _cover.value > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _cover,
                  builder: (context, _) {
                    final t = _cover.value;
                    if (t <= 0) return const SizedBox.shrink();

                    // Snap to solid black quickly so content never bleeds through.
                    final shell = Curves.easeOut
                        .transform((t / 0.28).clamp(0.0, 1.0));

                    return Opacity(
                      opacity: shell.clamp(0.0, 1.0),
                      child: ColoredBox(
                        color: AppColors.background,
                        child: Center(
                          child: Opacity(
                            opacity: _logoOpacity.value.clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: _logoScale.value,
                              child: AppLogoMark(
                                size: SplashTiming.logoSize,
                                emphasized: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _RefreshOverlay(
              pull: _pull,
              refreshing: _refreshing,
              cover: _cover,
              trigger: _trigger,
              topOffset: widget.orbTopOffset,
              minPull: widget.orbMinPull,
            ),
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
    required this.cover,
    required this.trigger,
    required this.topOffset,
    required this.minPull,
  });

  final ValueNotifier<double> pull;
  final ValueNotifier<bool> refreshing;
  final AnimationController cover;
  final double trigger;
  final double topOffset;
  final double minPull;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: refreshing,
      builder: (context, isRefreshing, _) {
        return ValueListenableBuilder<double>(
          valueListenable: pull,
          builder: (context, pullpx, _) {
            if (cover.value > 0.02) return const SizedBox.shrink();
            if (pullpx < minPull && !isRefreshing) {
              return const SizedBox.shrink();
            }

            final progress = (pullpx / trigger).clamp(0.0, 1.0);
            final armed = pullpx >= trigger;
            const orbSize = 38.0;
            final gap = math.min(pullpx, trigger);
            // Sit just above the rubber-banded content edge; padding stays >= 0.
            final top = math.max(0.0, gap - orbSize - 8);

            return Padding(
              padding: EdgeInsets.only(top: top),
              child: Align(
                alignment: Alignment.topCenter,
                child: Transform.translate(
                  offset: Offset(0, topOffset),
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: _RefreshOrb(
                        progress: progress,
                        armed: armed,
                      ),
                    ),
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
    required this.armed,
  });

  final double progress;
  final bool armed;

  @override
  Widget build(BuildContext context) {
    final eased = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final scale = 0.7 + eased * 0.3;
    final opacity = Curves.easeOut.transform(progress);

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
                _OrbBackdrop(active: armed),
                CustomPaint(
                  size: const Size(38, 38),
                  painter: _PullRingPainter(
                    progress: progress,
                    armed: armed,
                  ),
                ),
                AppLogoMark(
                  size: 18,
                  emphasized: armed,
                  opacity: 0.6 + progress * 0.4,
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
              ? AppColors.ui.withValues(alpha: 0.5)
              : AppColors.glassBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: active
                ? AppColors.ui.withValues(alpha: 0.18)
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
    ..color = AppColors.ui
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
      _arc,
    );
  }

  @override
  bool shouldRepaint(_PullRingPainter old) =>
      old.progress != progress || old.armed != armed;
}

/// Pull-to-refresh with a full-screen logo curtain while loading.
class AppRefreshScroll extends StatelessWidget {
  const AppRefreshScroll({
    super.key,
    required this.child,
    this.orbTopOffset = 0,
    this.orbMinPull = 0.5,
  });

  final Widget child;

  /// Nudge orb vertically after layout (negative = slightly higher).
  final double orbTopOffset;

  /// Minimum pull distance before the orb appears.
  final double orbMinPull;

  @override
  Widget build(BuildContext context) {
    return AppRefreshIndicator(
      onRefresh: () => refreshAppData(context),
      orbTopOffset: orbTopOffset,
      orbMinPull: orbMinPull,
      child: child,
    );
  }
}
