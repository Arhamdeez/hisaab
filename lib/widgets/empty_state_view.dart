import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_decorations.dart';

/// Centered empty placeholder — icon, title, optional subtitle.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = iconColor ?? AppColors.textMuted;
    final iconSize = compact ? 48.0 : 56.0;
    final glyphSize = compact ? 22.0 : 26.0;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 24 : 40,
          vertical: compact ? 16 : 24,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: AppDecorations.iconBadge(tint),
              child: Icon(icon, color: tint, size: glyphSize),
            ),
            SizedBox(height: compact ? 14 : 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: (compact
                      ? theme.textTheme.titleMedium
                      : theme.textTheme.headlineMedium)
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (subtitle != null) ...[
              SizedBox(height: compact ? 6 : 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Wraps [child] so it fills the viewport and stays vertically centered
/// (works inside pull-to-refresh scroll views).
class CenteredScrollEmpty extends StatelessWidget {
  const CenteredScrollEmpty({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        );
      },
    );
  }
}
