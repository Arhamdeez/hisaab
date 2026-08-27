import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
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

/// Floating tab bar. Starts compact; tap blooms it into the labeled bar.
class GlassBottomNavBar extends StatefulWidget {
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
  static const _barHeight = 68.0;
  static const _compactHeight = 52.0;
  static const _outerHPad = 18.0;
  static const _glassPaddingV = 10.0;
  static const _collapseDelay = Duration(milliseconds: 1400);
  static const _expandDuration = Duration(milliseconds: 420);
  static const _collapseDuration = Duration(milliseconds: 480);
  static const _pillDuration = Duration(milliseconds: 280);
  static const _morphCurve = Cubic(0.22, 1.0, 0.36, 1.0);
  static const _collapseCurve = Cubic(0.4, 0.0, 0.6, 1.0);
  static const _pillCurve = Cubic(0.22, 1.0, 0.36, 1.0);

  static double reservedHeight(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final outerBottom = bottomInset > 0 ? bottomInset + 8 : 18.0;
    return _barHeight + _glassPaddingV + outerBottom + 12;
  }

  @override
  State<GlassBottomNavBar> createState() => _GlassBottomNavBarState();
}

class _GlassBottomNavBarState extends State<GlassBottomNavBar>
    with TickerProviderStateMixin {
  AnimationController? _expandCtrl;
  AnimationController? _pillCtrl;
  CurvedAnimation? _expand;
  Listenable? _anim;
  double _pillFrom = 0;
  double _pillTo = 0;
  Timer? _collapseTimer;

  @override
  void initState() {
    super.initState();
    _pillFrom = widget.selectedIndex.toDouble();
    _pillTo = _pillFrom;
    _ensureAnim();
  }

  @override
  void didUpdateWidget(GlassBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureAnim();
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _expandThenCollapse();
      _movePill(widget.selectedIndex);
    }
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    _expand?.dispose();
    _expandCtrl?.dispose();
    _pillCtrl?.dispose();
    super.dispose();
  }

  void _ensureAnim() {
    _expandCtrl ??= AnimationController(
      vsync: this,
      duration: GlassBottomNavBar._expandDuration,
      reverseDuration: GlassBottomNavBar._collapseDuration,
      value: 0,
    );
    _pillCtrl ??= AnimationController(
      vsync: this,
      duration: GlassBottomNavBar._pillDuration,
      value: 1,
    );
    _expand ??= CurvedAnimation(
      parent: _expandCtrl!,
      curve: GlassBottomNavBar._morphCurve,
      reverseCurve: GlassBottomNavBar._collapseCurve,
    );
    _anim ??= Listenable.merge([_expandCtrl!, _pillCtrl!]);
  }

  double get _expandT => (_expand?.value ?? 0).clamp(0.0, 1.0);

  double get _labelT {
    final v = (_expandCtrl?.value ?? 0).clamp(0.0, 1.0);
    return const Interval(
      0.28,
      0.78,
      curve: Curves.easeOutCubic,
    ).transform(v);
  }

  double get _pillIndex {
    final t = GlassBottomNavBar._pillCurve.transform(
      (_pillCtrl?.value ?? 1).clamp(0.0, 1.0),
    );
    return lerpDouble(_pillFrom, _pillTo, t) ?? _pillTo;
  }

  void _movePill(int index) {
    final target = index.toDouble();
    if ((_pillIndex - target).abs() < 0.001) {
      _pillFrom = target;
      _pillTo = target;
      _pillCtrl?.value = 1;
      return;
    }
    _pillFrom = _pillIndex;
    _pillTo = target;
    _pillCtrl?.forward(from: 0);
  }

  void _scheduleCollapse() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(GlassBottomNavBar._collapseDelay, () {
      if (!mounted) return;
      _expandCtrl?.reverse();
    });
  }

  void _expandThenCollapse() {
    _collapseTimer?.cancel();
    _expandCtrl?.forward();
    _scheduleCollapse();
  }

  void _onTap(int index) {
    HapticFeedback.selectionClick();
    _expandThenCollapse();
    if (index != widget.selectedIndex) {
      widget.onSelected(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    _ensureAnim();
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final count = widget.destinations.length;
    final compactWidth = 56.0 * count + 16;

    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          GlassBottomNavBar._outerHPad,
          0,
          GlassBottomNavBar._outerHPad,
          bottomInset > 0 ? bottomInset + 8 : 18,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth;
            return Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedBuilder(
                animation: _anim!,
                builder: (context, _) {
                  final t = _expandT;
                  return _Island(
                    width: lerpDouble(
                          compactWidth.clamp(0.0, maxW),
                          maxW,
                          t,
                        ) ??
                        maxW,
                    height: lerpDouble(
                          GlassBottomNavBar._compactHeight,
                          GlassBottomNavBar._barHeight,
                          t,
                        ) ??
                        GlassBottomNavBar._barHeight,
                    destinations: widget.destinations,
                    selectedIndex: widget.selectedIndex,
                    pillIndex: _pillIndex,
                    labelT: _labelT,
                    onTap: _onTap,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Island extends StatelessWidget {
  const _Island({
    required this.width,
    required this.height,
    required this.destinations,
    required this.selectedIndex,
    required this.pillIndex,
    required this.labelT,
    required this.onTap,
  });

  final double width;
  final double height;
  final List<GlassNavDestination> destinations;
  final int selectedIndex;
  final double pillIndex;
  final double labelT;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final count = destinations.length;
    const pad = 6.0;
    const inset = 3.0;
    final radius = height / 2;
    final innerW = (width - pad * 2).clamp(0.0, double.infinity);
    final slotWidth = count > 0 ? innerW / count : innerW;
    final pillWidth = (slotWidth - inset * 2).clamp(0.0, innerW);
    final pillRadius = ((height - pad * 2 - inset * 2) / 2).clamp(10.0, 22.0);

    return RepaintBoundary(
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: AppColors.navBarFill,
            border: Border.all(color: AppColors.glassBorder, width: 0.9),
            boxShadow: const [
              BoxShadow(
                color: Color(0x8C000000),
                blurRadius: 16,
                offset: Offset(0, 6),
                spreadRadius: -6,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius - 0.5),
            child: Padding(
              padding: const EdgeInsets.all(pad),
              child: Stack(
                children: [
                  Positioned(
                    left: pillIndex * slotWidth + inset,
                    top: inset,
                    bottom: inset,
                    width: pillWidth,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(pillRadius),
                        color: AppColors.ui,
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
                            labelT: labelT,
                            onTap: () => onTap(i),
                          ),
                        ),
                    ],
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
    required this.labelT,
    required this.onTap,
  });

  final GlassNavDestination destination;
  final bool selected;
  final double labelT;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? AppColors.textOnPrimary : AppColors.textDim;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _NavIcon(
            icon: selected ? destination.selectedIcon : destination.icon,
            color: color,
            badgeCount: destination.badgeCount,
          ),
          ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: labelT,
              child: Opacity(
                opacity: labelT,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 2),
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style:
                        (theme.textTheme.bodySmall ?? const TextStyle())
                            .copyWith(
                      fontSize: 10,
                      height: 1.1,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: color,
                      letterSpacing: selected ? 0.12 : 0.04,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.color,
    this.badgeCount,
  });

  final IconData icon;
  final Color color;
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
