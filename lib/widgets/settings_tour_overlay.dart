import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import 'glass_container.dart';

class SettingsTourStep {
  const SettingsTourStep({
    required this.targetKey,
    required this.title,
    required this.body,
    required this.icon,
  });

  final GlobalKey targetKey;
  final String title;
  final String body;
  final IconData icon;
}

/// First-visit spotlight tour for Settings and Home.
class SettingsTourOverlay extends StatefulWidget {
  const SettingsTourOverlay({
    super.key,
    required this.steps,
    required this.scrollController,
    required this.onComplete,
    this.tooltipReserve = 268,
    this.bottomObstruction = 0,
    this.initialDelay = Duration.zero,
    this.scrollToTarget = true,
  });

  final List<SettingsTourStep> steps;
  final ScrollController scrollController;
  final VoidCallback onComplete;

  /// Bottom space reserved for the tooltip card (matches scroll padding).
  final double tooltipReserve;

  /// Height of UI sitting above the screen bottom (e.g. floating nav bar).
  final double bottomObstruction;

  /// Wait before focusing the first step (e.g. hero intro animation).
  final Duration initialDelay;

  /// When false, skips [Scrollable.ensureVisible] (Home targets are already on screen).
  final bool scrollToTarget;

  @override
  State<SettingsTourOverlay> createState() => _SettingsTourOverlayState();
}

class _SettingsTourOverlayState extends State<SettingsTourOverlay>
    with SingleTickerProviderStateMixin {
  static const _holePadH = 10.0;
  static const _holePadV = 12.0;
  static const _tooltipGap = 18.0;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  final _tooltipKey = GlobalKey();

  int _step = 0;
  RRect? _spotlight;
  bool _visible = false;
  bool _layoutReady = false;
  double _tooltipTop = 0;
  Timer? _spotlightTimer;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic);
    WidgetsBinding.instance.addPostFrameCallback((_) => _beginTour());
  }

  @override
  void dispose() {
    _spotlightTimer?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _startSpotlightRefresh() {
    _spotlightTimer?.cancel();
    _spotlightTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!mounted || !_visible) return;
      _refreshSpotlightForCurrentStep();
    });
  }

  void _refreshSpotlightForCurrentStep() {
    final target = _rectFor(widget.steps[_step].targetKey);
    if (target == null) return;
    final next = _spotlightFor(target);
    if (next == null) return;
    final changed = _spotlight?.outerRect != next.outerRect;
    if (changed) {
      setState(() => _spotlight = next);
    }
    _layoutTooltip();
  }

  Future<void> _beginTour() async {
    if (widget.initialDelay > Duration.zero) {
      await Future<void>.delayed(widget.initialDelay);
      if (!mounted) return;
    }

    await _prepareStep(0);
    if (!mounted) return;

    setState(() {
      _visible = true;
      _layoutReady = false;
    });

    await _measureTooltipLayout();
    if (!mounted) return;

    setState(() => _layoutReady = true);
    _startSpotlightRefresh();
    await _fadeCtrl.forward();
  }

  Future<void> _prepareStep(int index) async {
    if (widget.scrollToTarget) {
      final ctx = widget.steps[index].targetKey.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 480),
          curve: Curves.easeOutCubic,
          alignment: 0.06,
        );
      }
    } else {
      // Let any in-flight hero / toggle animations settle without scrolling.
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }

    if (!mounted) return;

    // Retry until the target is laid out (GlobalKey can lag several frames).
    for (var i = 0; i < 40; i++) {
      final target = _rectFor(widget.steps[index].targetKey);
      if (target != null) {
        setState(() {
          _step = index;
          _spotlight = _spotlightFor(target);
        });
        return;
      }
      await SchedulerBinding.instance.endOfFrame;
      if (!mounted) return;
    }

    // Still show the tour — spotlight will attach on the next refresh tick.
    setState(() {
      _step = index;
      _spotlight = null;
    });
  }

  Future<void> _measureTooltipLayout() async {
    for (var pass = 0; pass < 3; pass++) {
      await SchedulerBinding.instance.endOfFrame;
      if (!mounted) return;
      _layoutTooltip();
    }
  }

  RRect? _spotlightFor(Rect? target) {
    if (target == null) return null;
    return RRect.fromRectAndRadius(
      Rect.fromLTRB(
        target.left - _holePadH,
        target.top - _holePadV,
        target.right + _holePadH,
        target.bottom + _holePadV,
      ),
      const Radius.circular(AppRadius.lg + 2),
    );
  }

  Rect? _rectFor(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    return topLeft & box.size;
  }

  void _layoutTooltip() {
    if (!mounted) return;

    final screen = MediaQuery.sizeOf(context);
    final topSafe = MediaQuery.paddingOf(context).top;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final maxBottom =
        screen.height - bottomSafe - widget.bottomObstruction - 12;

    final tooltipBox =
        _tooltipKey.currentContext?.findRenderObject() as RenderBox?;
    final tooltipH =
        tooltipBox?.hasSize == true ? tooltipBox!.size.height : 220.0;

    double top;
    if (_spotlight == null) {
      top = maxBottom - tooltipH - 24;
    } else {
      final hole = _spotlight!.outerRect;
      final spaceBelow = maxBottom - hole.bottom - _tooltipGap;
      final spaceAbove = hole.top - topSafe - 12 - _tooltipGap;

      if (spaceBelow >= tooltipH) {
        top = hole.bottom + _tooltipGap;
      } else if (spaceAbove >= tooltipH) {
        top = hole.top - tooltipH - _tooltipGap;
      } else if (spaceAbove >= spaceBelow) {
        top = (hole.top - tooltipH - _tooltipGap)
            .clamp(topSafe + 12, maxBottom - tooltipH);
      } else {
        top = (hole.bottom + _tooltipGap)
            .clamp(topSafe + 12, maxBottom - tooltipH);
      }
    }

    if ((_tooltipTop - top).abs() > 0.5) {
      setState(() => _tooltipTop = top);
    }
  }

  Future<void> _next() async {
    HapticFeedback.lightImpact();
    if (_step >= widget.steps.length - 1) {
      _finish();
      return;
    }
    await _fadeCtrl.reverse();
    if (!mounted) return;
    setState(() => _layoutReady = false);
    await _prepareStep(_step + 1);
    if (!mounted) return;
    await _measureTooltipLayout();
    if (!mounted) return;
    setState(() => _layoutReady = true);
    await _fadeCtrl.forward();
  }

  void _finish() {
    HapticFeedback.mediumImpact();
    _spotlightTimer?.cancel();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final step = widget.steps[_step];
    final showContent = _layoutReady;

    final tooltip = _TourTooltipCard(
      key: _tooltipKey,
      step: step,
      stepIndex: _step,
      stepCount: widget.steps.length,
      onSkip: _finish,
      onNext: _next,
      isLast: _step >= widget.steps.length - 1,
    );

    return IgnorePointer(
      ignoring: !showContent,
      child: FadeTransition(
        opacity: showContent ? _fade : const AlwaysStoppedAnimation(0),
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipPath(
                clipper: _SpotlightClipper(spotlight: _spotlight),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.78),
                  ),
                ),
              ),
              CustomPaint(
                painter: _SpotlightPainter(spotlight: _spotlight),
                child: const SizedBox.expand(),
              ),
              AbsorbPointer(
                child: const SizedBox.expand(),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: AppSpacing.pageH,
                right: AppSpacing.pageH,
                top: _tooltipTop,
                child: tooltip,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TourTooltipCard extends StatelessWidget {
  const _TourTooltipCard({
    super.key,
    required this.step,
    required this.stepIndex,
    required this.stepCount,
    required this.onSkip,
    required this.onNext,
    required this.isLast,
  });

  final SettingsTourStep step;
  final int stepIndex;
  final int stepCount;
  final VoidCallback onSkip;
  final VoidCallback onNext;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.18),
            blurRadius: 32,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: GlassCard(
        accentGlow: true,
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 3,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.xl),
                ),
                gradient: LinearGradient(
                  colors: [
                    AppColors.brand,
                    AppColors.brandGlow.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.brand.withValues(alpha: 0.28),
                              AppColors.brand.withValues(alpha: 0.12),
                            ],
                          ),
                          border: Border.all(
                            color: AppColors.brand.withValues(alpha: 0.55),
                          ),
                        ),
                        child: Icon(step.icon, color: AppColors.brandGlow, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Step ${stepIndex + 1} of $stepCount',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.brandGlow.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: onSkip,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textMuted,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('Skip'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    step.body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(stepCount, (i) {
                          final active = i == stepIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.only(right: 6),
                            width: active ? 20 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(99),
                              color: active
                                  ? AppColors.brand
                                  : AppColors.textDim,
                              boxShadow: active
                                  ? [
                                      BoxShadow(
                                        color: AppColors.brand
                                            .withValues(alpha: 0.45),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                            ),
                          );
                        }),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: onNext,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.ui,
                          foregroundColor: AppColors.textOnPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        child: Text(isLast ? 'Done' : 'Next'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Clips the blur layer so the spotlight hole stays sharp and undimmed.
class _SpotlightClipper extends CustomClipper<Path> {
  _SpotlightClipper({this.spotlight});

  final RRect? spotlight;

  @override
  Path getClip(Size size) {
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    if (spotlight != null) {
      path.addRRect(spotlight!);
      path.fillType = PathFillType.evenOdd;
    }
    return path;
  }

  @override
  bool shouldReclip(covariant _SpotlightClipper oldClipper) =>
      oldClipper.spotlight != spotlight;
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({this.spotlight});

  final RRect? spotlight;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Rect.fromLTWH(0, 0, size.width, size.height);

    final dimPath = Path()..addRect(full);
    if (spotlight != null) {
      dimPath.addRRect(spotlight!);
      dimPath.fillType = PathFillType.evenOdd;
    }
    canvas.drawPath(
      dimPath,
      Paint()..color = Colors.black.withValues(alpha: 0.42),
    );

    if (spotlight == null) return;

    final hole = spotlight!;

    canvas.drawRRect(
      hole.inflate(6),
      Paint()
        ..color = AppColors.brand.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    canvas.drawRRect(
      hole,
      Paint()
        ..color = AppColors.brand
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.25,
    );

    canvas.drawRRect(
      hole.deflate(1.5),
      Paint()
        ..color = AppColors.brandGlow.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.spotlight != spotlight;
}
