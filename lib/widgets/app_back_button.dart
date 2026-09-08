import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Navigation back control.
///
/// Android keeps the Material arrow. iOS uses a chevron. Layout and color
/// stay the same so screens do not fork by platform.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    return IconButton(
      onPressed: onPressed ?? () => Navigator.of(context).pop(),
      icon: Icon(
        ios ? Icons.chevron_left_rounded : Icons.arrow_back_rounded,
      ),
      color: AppColors.textSecondary,
    );
  }
}
