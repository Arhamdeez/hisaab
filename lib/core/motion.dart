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

  /// Soft content swap for keyed children (month labels, etc.).
  ///
  /// Never stacks outgoing + incoming in a [Stack] — that is what caused month
  /// names to overlay when chevrons were tapped quickly. Only the new child is
  /// laid out; it fades/slides in alone.
  static Widget softSwap({
    required Key key,
    required Widget child,
    Duration duration = medium,
    Offset? slideBegin = const Offset(0, 0.03),
  }) {
    return AnimatedSwitcher(
      duration: duration,
      // No reverse/outgoing phase — avoids dual-label ghosts on fast switches.
      reverseDuration: Duration.zero,
      switchInCurve: easeOut,
      switchOutCurve: easeIn,
      layoutBuilder: (current, previous) {
        return current ?? const SizedBox.shrink();
      },
      transitionBuilder: (child, animation) {
        final fade = CurvedAnimation(
          parent: animation,
          curve: easeOut,
        );
        Widget result = FadeTransition(opacity: fade, child: child);
        if (slideBegin != null) {
          result = SlideTransition(
            position: Tween<Offset>(
              begin: slideBegin,
              end: Offset.zero,
            ).animate(fade),
            child: result,
          );
        }
        return result;
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
