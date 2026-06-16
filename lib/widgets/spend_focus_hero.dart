import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/utils/formatters.dart';
import 'app_logo_mark.dart';
import 'glass_container.dart';

const _kHeroAnimDuration = Duration(milliseconds: 520);

/// Fade out → swap content → fade in so two states never stack on screen.
class _SequentialFadeSwap extends StatefulWidget {
  const _SequentialFadeSwap({
    required this.swapKey,
    required this.child,
    this.duration = _kHeroAnimDuration,
    this.alignment = Alignment.center,
  });

  final Object swapKey;
  final Widget child;
  final Duration duration;
  final Alignment alignment;

  @override
  State<_SequentialFadeSwap> createState() => _SequentialFadeSwapState();
}

class _SequentialFadeSwapState extends State<_SequentialFadeSwap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _fade;
  late Widget _shown;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _shown = widget.child;
    final phase = Duration(
      milliseconds: widget.duration.inMilliseconds ~/ 2,
    );
    _controller = AnimationController(vsync: this, duration: phase);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.value = 1;
  }

  @override
  void didUpdateWidget(_SequentialFadeSwap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = Duration(
        milliseconds: widget.duration.inMilliseconds ~/ 2,
      );
    }
    if (oldWidget.swapKey != widget.swapKey) {
      _runSwap(++_generation);
    } else {
      _shown = widget.child;
    }
  }

  Future<void> _runSwap(int generation) async {
    await _controller.reverse();
    if (!mounted || generation != _generation) return;
    setState(() => _shown = widget.child);
    await _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Align(
        alignment: widget.alignment,
        widthFactor: 1,
        heightFactor: 1,
        child: _shown,
      ),
    );
  }
}

class _FadeSwapText extends StatelessWidget {
  const _FadeSwapText({
    required this.text,
    this.style,
    this.textAlign,
    this.duration = _kHeroAnimDuration,
    this.alignment = Alignment.centerLeft,
    this.maxLines = 2,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final Duration duration;
  final Alignment alignment;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final resolved = style ?? DefaultTextStyle.of(context).style;
    return _SequentialFadeSwap(
      swapKey: text,
      duration: duration,
      alignment: alignment,
      child: Text(
        text,
        textAlign: textAlign,
        maxLines: maxLines,
        softWrap: true,
        style: resolved,
      ),
    );
  }
}

/// The single focal element of Home: total spent, shown big.
/// When income is enabled it expands into a richer, branded view with a
/// premium budget slider and income/remaining stats.
class SpendFocusHero extends StatefulWidget {
  const SpendFocusHero({
    super.key,
    required this.totalSpent,
    required this.income,
    required this.showIncome,
    required this.monthLabel,
    required this.transactionCount,
    this.trackInwardFlow = false,
    this.totalReceived = 0,
  });

  final double totalSpent;
  final double income;
  final bool showIncome;
  final String monthLabel;
  final int transactionCount;
  final bool trackInwardFlow;
  final double totalReceived;

  @override
  State<SpendFocusHero> createState() => _SpendFocusHeroState();
}

class _SpendFocusHeroState extends State<SpendFocusHero> {
  /// When true, the hero headline shows cash in − cash out instead of cash out.
  bool _showNetOnMain = false;

  /// Anchor for the amount tween when toggling cash out ↔ net.
  double _amountAnimFrom = 0;

  @override
  void initState() {
    super.initState();
    _amountAnimFrom = widget.totalSpent;
  }

  @override
  void didUpdateWidget(SpendFocusHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    final net = widget.totalReceived - widget.totalSpent;
    final heroAmount = _showNetOnMain ? net.abs() : widget.totalSpent;
    final oldNet = oldWidget.totalReceived - oldWidget.totalSpent;
    final oldHeroAmount =
        _showNetOnMain ? oldNet.abs() : oldWidget.totalSpent;
    if (oldHeroAmount != heroAmount) {
      _amountAnimFrom = heroAmount;
    }
  }

  void _toggleNet() {
    final net = widget.totalReceived - widget.totalSpent;
    final leavingAmount =
        _showNetOnMain ? net.abs() : widget.totalSpent;
    _amountAnimFrom = leavingAmount;
    setState(() => _showNetOnMain = !_showNetOnMain);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasIncome = widget.showIncome && widget.income > 0;
    final cashFlowOnly = widget.trackInwardFlow && !widget.showIncome;
    final remaining = widget.income - widget.totalSpent;
    final net = widget.totalReceived - widget.totalSpent;

    final showNetHero = widget.trackInwardFlow && _showNetOnMain;
    final heroLabel = showNetHero
        ? (net >= 0 ? 'NET CASH' : 'NET OUT')
        : (cashFlowOnly ? 'CASH OUT' : 'TOTAL SPENT');
    final heroAmount = showNetHero ? net.abs() : widget.totalSpent;
    final heroColor = showNetHero
        ? (net >= 0 ? AppColors.saved : AppColors.primary)
        : AppColors.textPrimary;

    return GlassContainer(
      radius: AppRadius.xl,
      blur: 12,
      tint: AppColors.glassFillStrong,
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _HeroHeadline(
            label: heroLabel,
            amount: heroAmount,
            amountFrom: _amountAnimFrom,
            color: heroColor,
            mutedLabel: !showNetHero,
            onAmountAnimEnd: () {
              if (_amountAnimFrom != heroAmount) {
                setState(() => _amountAnimFrom = heroAmount);
              }
            },
          ),
          const SizedBox(height: 8),
          Text(
            cashFlowOnly
                ? 'Cash out · ${widget.monthLabel}'
                : hasIncome
                    ? 'in ${widget.monthLabel}'
                    : '${widget.transactionCount} transaction${widget.transactionCount == 1 ? '' : 's'} · ${widget.monthLabel}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          if (widget.trackInwardFlow &&
              (widget.totalReceived > 0 || widget.totalSpent > 0)) ...[
            const SizedBox(height: 12),
            _NetPositionChip(net: net),
          ],
          if (widget.trackInwardFlow) ...[
            SizedBox(
              height: widget.totalReceived > 0 || widget.totalSpent > 0
                  ? 10
                  : 24,
            ),
            if (cashFlowOnly &&
                (widget.totalReceived > 0 || widget.totalSpent > 0)) ...[
              _CashFlowGauge(
                received: widget.totalReceived,
                spent: widget.totalSpent,
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
            _NetBalanceToggle(
              active: _showNetOnMain,
              cashIn: widget.totalReceived,
              cashOut: widget.totalSpent,
              net: net,
              onTap: _toggleNet,
            ),
          ],
          if (hasIncome) ...[
            if (widget.trackInwardFlow) const SizedBox(height: 28),
            BudgetSlider(spent: widget.totalSpent, total: widget.income),
            const SizedBox(height: 22),
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _HeroStat(
                      icon: Icons.south_west_rounded,
                      label: 'Income',
                      value: formatCompactCurrency(widget.income),
                      color: AppColors.income,
                    ),
                  ),
                  const VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: AppColors.border,
                    indent: 4,
                    endIndent: 4,
                  ),
                  Expanded(
                    child: _HeroStat(
                      icon: Icons.savings_outlined,
                      label: remaining >= 0 ? 'Left' : 'Over',
                      value: formatCompactCurrency(remaining.abs()),
                      color: remaining >= 0 ? AppColors.saved : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact net surplus/deficit readout for the hero card.
class _NetPositionChip extends StatelessWidget {
  const _NetPositionChip({required this.net});

  final double net;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSurplus = net >= 0;
    final accent = isSurplus ? AppColors.income : AppColors.primaryGlow;
    final label = isSurplus ? 'Net surplus' : 'Net deficit';
    final icon = isSurplus
        ? Icons.trending_up_rounded
        : Icons.trending_down_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.16),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, size: 15, color: accent),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '·',
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            formatCompactCurrency(net.abs()),
            style: theme.textTheme.titleSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated hero label + amount for cash out ↔ net toggle.
class _HeroHeadline extends StatelessWidget {
  const _HeroHeadline({
    required this.label,
    required this.amount,
    required this.amountFrom,
    required this.color,
    required this.mutedLabel,
    required this.onAmountAnimEnd,
  });

  final String label;
  final double amount;
  final double amountFrom;
  final Color color;
  final bool mutedLabel;
  final VoidCallback onAmountAnimEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelColor =
        mutedLabel ? AppColors.textMuted : color.withValues(alpha: 0.85);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppLogoMark(size: 18, opacity: 0.95),
            const SizedBox(width: 7),
            AnimatedDefaultTextStyle(
              duration: _kHeroAnimDuration,
              curve: Curves.easeOutCubic,
              style: theme.textTheme.bodySmall!.copyWith(
                color: labelColor,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w600,
              ),
              child: _FadeSwapText(
                text: label,
                alignment: Alignment.center,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TweenAnimationBuilder<double>(
          duration: _kHeroAnimDuration,
          curve: Curves.easeOutCubic,
          tween: Tween<double>(begin: amountFrom, end: amount),
          onEnd: onAmountAnimEnd,
          builder: (context, value, _) {
            return AnimatedDefaultTextStyle(
              duration: _kHeroAnimDuration,
              curve: Curves.easeOutCubic,
              style: theme.textTheme.displayLarge!.copyWith(
                fontSize: 54,
                fontWeight: FontWeight.w700,
                letterSpacing: -2,
                height: 1,
                color: color,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatCurrency(value),
                  maxLines: 1,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Full-width control — tap to show net (cash in − cash out) on the hero.
class _NetBalanceToggle extends StatefulWidget {
  const _NetBalanceToggle({
    required this.active,
    required this.cashIn,
    required this.cashOut,
    required this.net,
    required this.onTap,
  });

  final bool active;
  final double cashIn;
  final double cashOut;
  final double net;
  final VoidCallback onTap;

  @override
  State<_NetBalanceToggle> createState() => _NetBalanceToggleState();
}

class _NetBalanceToggleState extends State<_NetBalanceToggle> {
  static const _animDuration = _kHeroAnimDuration;

  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final netColor = widget.net >= 0 ? AppColors.income : AppColors.primaryGlow;

    final inactiveFooter = Column(
      children: [
        const SizedBox(height: 12),
        const Divider(height: 1, color: AppColors.borderLight),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _NetFlowStat(
                label: 'Cash in',
                value: formatCompactCurrency(widget.cashIn),
                color: AppColors.income,
              ),
            ),
            Container(
              width: 1,
              height: 32,
              color: AppColors.borderLight,
            ),
            Expanded(
              child: _NetFlowStat(
                label: 'Cash out',
                value: formatCompactCurrency(widget.cashOut),
                color: AppColors.primaryGlow,
              ),
            ),
          ],
        ),
      ],
    );

    final activeFooter = Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        'Tap to return to cash out',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: _animDuration,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            color: widget.active
                ? netColor.withValues(alpha: 0.14)
                : AppColors.backgroundElevated,
            border: Border.all(
              color: widget.active
                  ? netColor.withValues(alpha: 0.65)
                  : AppColors.glassBorder,
              width: 1.25,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: _animDuration,
                    curve: Curves.easeOutCubic,
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.active
                          ? netColor.withValues(alpha: 0.22)
                          : AppColors.surfaceHigh,
                      border: Border.all(
                        color: widget.active
                            ? netColor.withValues(alpha: 0.7)
                            : AppColors.borderLight,
                      ),
                    ),
                    child: _SequentialFadeSwap(
                      swapKey: widget.active,
                      duration: _animDuration,
                      child: Icon(
                        widget.active
                            ? Icons.check_rounded
                            : Icons.compare_arrows_rounded,
                        size: 18,
                        color:
                            widget.active ? netColor : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _FadeSwapText(
                        text: widget.active
                            ? 'Net shown on main'
                            : 'Show net balance',
                        duration: _animDuration,
                        style: theme.textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.1,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: _animDuration,
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                clipBehavior: Clip.hardEdge,
                child: _SequentialFadeSwap(
                  swapKey: widget.active,
                  duration: _animDuration,
                  alignment: Alignment.topCenter,
                  child: widget.active ? activeFooter : inactiveFooter,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NetFlowStat extends StatelessWidget {
  const _NetFlowStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

/// In/out proportion bar for cash-flow-only mode (no income budget).
class _CashFlowGauge extends StatelessWidget {
  const _CashFlowGauge({required this.received, required this.spent});

  final double received;
  final double spent;

  @override
  Widget build(BuildContext context) {
    final total = received + spent;
    final inShare = total > 0 ? received / total : 0.5;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            if (inShare > 0)
              Expanded(
                flex: (inShare * 100).round().clamp(1, 100),
                child: const ColoredBox(color: AppColors.income),
              ),
            if (inShare < 1)
              Expanded(
                flex: ((1 - inShare) * 100).round().clamp(1, 100),
                child: const ColoredBox(color: AppColors.primary),
              ),
          ],
        ),
      ),
    );
  }
}

/// A premium, non-interactive budget gauge: a rounded track with a glowing
/// filled portion and a circular thumb sitting at the spent boundary.
class BudgetSlider extends StatelessWidget {
  const BudgetSlider({
    super.key,
    required this.spent,
    required this.total,
  });

  final double spent;
  final double total;

  static const _trackH = 12.0;
  static const _thumb = 22.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = total > 0 ? (spent / total).clamp(0.0, 1.0) : 0.0;

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final fillW = (w * pct).clamp(_trackH, w);
            final thumbLeft = (w * pct - _thumb / 2).clamp(0.0, w - _thumb);

            return SizedBox(
              height: _thumb,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: _trackH,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  Container(
                    height: _trackH,
                    width: fillW,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryDim, AppColors.primary],
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: thumbLeft,
                    child: Container(
                      width: _thumb,
                      height: _thumb,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.textPrimary,
                        border: Border.all(
                          color: AppColors.primary,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${formatPercent(pct * 100)} of income',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'of ${formatCompactCurrency(total)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
