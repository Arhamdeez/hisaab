import 'package:flutter/material.dart';

/// Shared motion tokens — keep transitions consistent and lightweight.
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 200);
  static const nav = Duration(milliseconds: 300);

  static const easeOut = Curves.easeOutCubic;
  static const easeInOut = Curves.easeInOutCubic;
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
