import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Keeps every tab mounted and raster-cached. Switching is instant — no
/// opacity or transform on full-screen pages (that was the stutter).
class PerformantTabView extends StatelessWidget {
  const PerformantTabView({
    super.key,
    required this.index,
    required this.children,
    this.duration = Duration.zero,
  });

  final int index;
  final List<Widget> children;

  /// Unused; kept so existing call sites compile.
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < children.length; i++)
          TickerMode(
            enabled: i == index,
            child: Offstage(
              offstage: i != index,
              child: RepaintBoundary(
                child: ColoredBox(
                  color: AppColors.background,
                  child: children[i],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
