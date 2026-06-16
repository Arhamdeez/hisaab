import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/utils/formatters.dart';
import 'app_logo_mark.dart';
import 'glass_container.dart';

/// The single focal element of Home: total spent, shown big.
/// When income is enabled it expands into a richer, branded view with a
/// premium budget slider and income/remaining stats.
class SpendFocusHero extends StatelessWidget {
  const SpendFocusHero({
    super.key,
    required this.totalSpent,
    required this.income,
    required this.showIncome,
    required this.monthLabel,
    required this.transactionCount,
  });

  final double totalSpent;
  final double income;
  final bool showIncome;
  final String monthLabel;
  final int transactionCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasIncome = showIncome && income > 0;
    final remaining = income - totalSpent;

    return GlassContainer(
      radius: AppRadius.xl,
      blur: 12,
      tint: AppColors.glassFillStrong,
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppLogoMark(size: 14, opacity: 0.55),
              const SizedBox(width: 7),
              Text(
                'TOTAL SPENT',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatCurrency(totalSpent),
              maxLines: 1,
              style: theme.textTheme.displayLarge?.copyWith(
                fontSize: 54,
                fontWeight: FontWeight.w700,
                letterSpacing: -2,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasIncome
                ? 'in $monthLabel'
                : '$transactionCount transaction${transactionCount == 1 ? '' : 's'} · $monthLabel',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          if (hasIncome) ...[
            const SizedBox(height: 28),
            BudgetSlider(spent: totalSpent, total: income),
            const SizedBox(height: 22),
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _HeroStat(
                      icon: Icons.south_west_rounded,
                      label: 'Income',
                      value: formatCompactCurrency(income),
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
                            color: Colors.black.withValues(alpha: 0.35),
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
