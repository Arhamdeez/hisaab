import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_decorations.dart';
import '../core/theme/app_spacing.dart';

class GlassNavDestination {
  const GlassNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badgeCount,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int? badgeCount;
}

/// Floating frosted tab bar with a sliding pill indicator.
class GlassBottomNavBar extends StatelessWidget {
  const GlassBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<GlassNavDestination> destinations;

  static const _iconSize = 20.0;
  static const _barHeight = 66.0;
  static const _outerHPad = 18.0;
  static const _glassPaddingV = 10.0;
  static const _innerPad = 4.0;

  /// Space to reserve at the bottom of scroll views so content clears the bar.
  static double reservedHeight(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final outerBottom = bottomInset > 0 ? bottomInset + 8 : 18.0;
    return _barHeight + _glassPaddingV + outerBottom + 12;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _outerHPad,
          0,
          _outerHPad,
          bottomInset > 0 ? bottomInset + 8 : 18,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppRadius.borderXxl,
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withValues(alpha: 0.65),
                blurRadius: 28,
                offset: const Offset(0, 14),
                spreadRadius: -4,
              ),
              BoxShadow(
                color: AppColors.ui.withValues(alpha: 0.06),
                blurRadius: 40,
                spreadRadius: -10,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: AppRadius.borderXxl,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: AppRadius.borderXxl,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.navBarFill,
                    AppColors.navBarFillDeep,
                    AppColors.navBarFillDeep,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
                border: Border.all(
                  color: AppColors.glassBorder,
                  width: 0.9,
                ),
              ),
              child: Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: AppRadius.borderXxl,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.glassHighlight.withValues(alpha: 0.16),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.45],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                AppColors.glassSpecular,
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(_innerPad),
                      child: SizedBox(
                        height: _barHeight - _innerPad * 2,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final count = destinations.length;
                            final slotWidth = constraints.maxWidth / count;
                            const indicatorInset = 2.0;

                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                AnimatedPositioned(
                                  duration: AppMotion.nav,
                                  curve: AppMotion.easeInOut,
                                  left: selectedIndex * slotWidth + indicatorInset,
                                  top: indicatorInset,
                                  bottom: indicatorInset,
                                  width: slotWidth - indicatorInset * 2,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: AppRadius.borderLg,
                                      color: AppColors.ui,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.ui
                                              .withValues(alpha: 0.18),
                                          blurRadius: 12,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    for (var i = 0; i < count; i++)
                                      Expanded(
                                        child: _NavItem(
                                          destination: destinations[i],
                                          selected: selectedIndex == i,
                                          onTap: () => onSelected(i),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final GlassNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        selected ? AppColors.textOnPrimary : AppColors.textDim;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderLg,
        splashColor: AppColors.ui.withValues(alpha: 0.12),
        highlightColor: AppColors.ui.withValues(alpha: 0.06),
        child: SizedBox(
          height: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _NavIcon(
                  icon: selected ? destination.selectedIcon : destination.icon,
                  color: selected ? AppColors.textOnPrimary : color,
                  selected: selected,
                  badgeCount: destination.badgeCount,
                ),
                const SizedBox(height: 2),
                Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        height: 1.0,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? AppColors.textOnPrimary : color,
                        letterSpacing: selected ? 0.12 : 0.04,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.color,
    required this.selected,
    this.badgeCount,
  });

  final IconData icon;
  final Color color;
  final bool selected;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final showBadge = badgeCount != null && badgeCount! > 0;

    return SizedBox(
      width: 26,
      height: 24,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        alignment: Alignment.center,
        children: [
          Icon(
            icon,
            size: GlassBottomNavBar._iconSize,
            color: color,
          ),
          if (showBadge)
            Positioned(
              top: -3,
              right: -1,
              child: Container(
                constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: AppRadius.borderPill,
                  border: Border.all(
                    color: AppColors.glassFillDeep,
                    width: 1.5,
                  ),
                  boxShadow: AppDecorations.heroGlow(),
                ),
                child: Text(
                  badgeCount! > 9 ? '9+' : '$badgeCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textOnPrimary,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
