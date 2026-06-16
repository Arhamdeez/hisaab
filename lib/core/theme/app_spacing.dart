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

/// One corner-radius scale — use these tokens everywhere so surfaces feel cohesive.
abstract final class AppRadius {
  /// Chart dots, bar caps, skeleton slivers.
  static const dot = 4.0;

  /// Skeleton lines, micro chips.
  static const xxs = 6.0;

  /// Status pills, compact badges.
  static const xs = 8.0;

  /// Small icon tiles, inner controls.
  static const sm = 12.0;

  /// Buttons, inputs, tappable rows.
  static const md = 14.0;

  /// Standard cards and grouped lists.
  static const lg = 20.0;

  /// Hero cards, charts, feature panels.
  static const xl = 24.0;

  /// Bottom nav, sheets, large floating shells.
  static const xxl = 28.0;

  /// Welcome / onboarding hero surfaces.
  static const hero = 32.0;

  /// 44pt square icon buttons — half-size yields a perfect circle.
  static const iconButton = 22.0;

  /// Fully rounded pills, dots, and capsules.
  static const pill = 999.0;

  static BorderRadius border(double value) => BorderRadius.circular(value);

  static BorderRadius get borderDot => border(dot);
  static BorderRadius get borderXs => border(xs);
  static BorderRadius get borderSm => border(sm);
  static BorderRadius get borderMd => border(md);
  static BorderRadius get borderLg => border(lg);
  static BorderRadius get borderXl => border(xl);
  static BorderRadius get borderXxl => border(xxl);
  static BorderRadius get borderHero => border(hero);
  static BorderRadius get borderIconButton => border(iconButton);
  static BorderRadius get borderPill => border(pill);
}
