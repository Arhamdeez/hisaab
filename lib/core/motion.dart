import 'package:flutter/material.dart';

/// Shared motion tokens — keep transitions consistent and premium.
abstract final class AppMotion {
  /// Press / micro feedback.
  static const instant = Duration(milliseconds: 120);

  /// Chips, toggles, icon swaps.
  static const fast = Duration(milliseconds: 200);

  /// Content swaps, sheets, result lists.
  static const medium = Duration(milliseconds: 320);

  /// Tab pill, nav chrome, tab page slides.
  static const nav = Duration(milliseconds: 300);

  /// Headline amounts, gauges, hero swaps.
  static const hero = Duration(milliseconds: 520);

  /// Tours, overlays, curtains.
  static const reveal = Duration(milliseconds: 480);

  static const easeOut = Curves.easeOutCubic;
  static const easeIn = Curves.easeInCubic;
  static const easeInOut = Curves.easeInOutCubic;
  static const emphasize = Curves.easeOutBack;
  static const glassFade = Curves.easeOut;

  /// Soft fade + slight rise used for list/filter content swaps.
  static Widget softSwap({
    required Key key,
    required Widget child,
    Duration duration = medium,
  }) {
    return AnimatedSwitcher(
      duration: duration,
      reverseDuration: fast,
      switchInCurve: easeOut,
      switchOutCurve: easeIn,
      layoutBuilder: (current, previous) {
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            ...previous,
            ?current,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        final fade = CurvedAnimation(
          parent: animation,
          curve: easeOut,
          reverseCurve: easeIn,
        );
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(fade);
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: KeyedSubtree(key: key, child: child),
    );
  }
}

/// Smooth overscroll on all platforms.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
}
