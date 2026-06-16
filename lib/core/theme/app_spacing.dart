import 'package:flutter/material.dart';

/// Consistent layout spacing across the app.
abstract final class AppSpacing {
  static const pageH = 20.0;
  static const section = 24.0;
  static const item = 12.0;
  static const navBottom = 112.0;

  static const pageHorizontal = EdgeInsets.symmetric(horizontal: pageH);
  static const page = EdgeInsets.fromLTRB(pageH, 16, pageH, navBottom);
}

/// One corner-radius scale, used everywhere so surfaces feel like one family.
abstract final class AppRadius {
  /// Chips, small icon tiles.
  static const sm = 12.0;

  /// Inner controls, buttons.
  static const md = 14.0;

  /// Standard cards & grouped lists.
  static const lg = 20.0;

  /// Feature surfaces (hero, charts).
  static const xl = 24.0;

  /// Fully rounded.
  static const pill = 999.0;
}
