import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Premium fade-through tab transition tuned for heavy screens.
///
/// Both pages stay permanently mounted with an identical widget structure —
/// only opacity and a small translate change per frame. That keeps each
/// page's raster cache (RepaintBoundary) valid across switches, so the GPU
/// just composites two cached layers instead of re-rasterizing the glass UI
/// mid-animation (which is what causes the hang/stutter).
class PerformantTabView extends StatefulWidget {
  const PerformantTabView({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 180),
  });

  final int index;
  final List<Widget> children;
  final Duration duration;

  @override
  State<PerformantTabView> createState() => _PerformantTabViewState();
}

class _PerformantTabViewState extends State<PerformantTabView>
    with SingleTickerProviderStateMixin {
  static const _drift = 24.0;

  late final AnimationController _controller;
  late int _currentIndex;
  late int _previousIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.index;
    _previousIndex = widget.index;
    _controller =
        AnimationController(vsync: this, duration: widget.duration, value: 1);
  }

  @override
  void didUpdateWidget(PerformantTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.index == _currentIndex) return;

    _previousIndex = _currentIndex;
    _currentIndex = widget.index;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final forward = _currentIndex >= _previousIndex;

        return Stack(
          fit: StackFit.expand,
          children: [
            for (var i = 0; i < widget.children.length; i++)
              _page(i, t, forward),
          ],
        );
      },
    );
  }

  Widget _page(int index, double t, bool forward) {
    final isCurrent = index == _currentIndex;
    final isPrevious = index == _previousIndex && !isCurrent;

    double opacity;
    double dx;

    if (isCurrent) {
      final tin = Curves.easeOutCubic.transform(t);
      opacity = tin;
      dx = (forward ? _drift : -_drift) * (1 - tin);
    } else if (isPrevious) {
      final out = Curves.easeIn.transform((t / 0.35).clamp(0.0, 1.0));
      opacity = 1 - out;
      dx = (forward ? -_drift : _drift) * out * 0.6;
    } else {
      opacity = 0;
      dx = 0;
    }

    // Constant structure every frame and between transitions: Opacity(0)
    // skips painting entirely, and the RepaintBoundary below keeps the
    // page's raster cached so switching back never re-rasterizes.
    return IgnorePointer(
      ignoring: !isCurrent,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(dx, 0),
          child: TickerMode(
            enabled: isCurrent,
            child: RepaintBoundary(
              child: ColoredBox(
                color: AppColors.background,
                child: widget.children[index],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
