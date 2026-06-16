import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';

/// Full-width page padding — content aligns to the leading edge.
class CenteredContent extends StatelessWidget {
  const CenteredContent({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: child,
    );
  }
}

/// Shorthand for standard horizontal page gutters.
class PageGutter extends StatelessWidget {
  const PageGutter({super.key, required this.child, this.top = 0, this.bottom = 0});

  final Widget child;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        top,
        AppSpacing.pageH,
        bottom,
      ),
      child: child,
    );
  }
}
