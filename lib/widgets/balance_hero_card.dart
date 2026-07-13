import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../widgets/glass_container.dart';
import '../core/utils/cash_flow.dart';
import '../core/utils/formatters.dart';

class BalanceHeroCard extends StatelessWidget {
  const BalanceHeroCard({
    super.key,
    required this.totalExpense,
    required this.totalIncome,
    this.showIncome = true,
    this.trackInwardFlow = false,
    this.totalReceived = 0,
  });

  final double totalExpense;
  final double totalIncome;
  final bool showIncome;
  final bool trackInwardFlow;
  final double totalReceived;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cashFlowOnly = trackInwardFlow && !showIncome;
    final flow = CashFlowMetrics(cashIn: totalReceived, cashOut: totalExpense);
    final hasIncome = showIncome && totalIncome > 0;
    final rawUsed = hasIncome ? totalExpense / totalIncome : 0.0;
    final usedPct = rawUsed.clamp(0.0, 1.0);
    final usedPercent = (rawUsed * 100).clamp(0.0, 999.0);
    final remaining = totalIncome - totalExpense;
    final netCash = flow.net;
    final cashOutRelative = flow.cashIn > 0
        ? '${formatPercent(flow.cashOutOfCashIn * 100)} of cash in'
        : null;

    return GlassContainer(
      radius: AppRadius.xl,
      enableBlur: false,
      accentGlow: true,
      tint: AppColors.glassFillStrong,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            cashFlowOnly ? 'Cash out' : 'Total spent',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
              letterSpacing: 0.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            formatCurrency(totalExpense),
            textAlign: TextAlign.center,
            style: theme.textTheme.displayLarge,
          ),
          if (cashFlowOnly && cashOutRelative != null) ...[
            const SizedBox(height: 8),
            Text(
              cashOutRelative,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (trackInwardFlow) ...[
            const SizedBox(height: 20),
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Cash in',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatCurrency(totalReceived),
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: AppColors.income,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Received',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
                    child: Column(
                      children: [
                        Text(
                          netCash >= 0 ? 'Net cash' : 'Net out',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatCurrency(netCash.abs()),
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: netCash >= 0
                                ? AppColors.income
                                : AppColors.expense,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (flow.cashIn > 0)
                          Text(
                            '${formatPercent((netCash / flow.cashIn * 100).abs())} of cash in',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (hasIncome) ...[
            const SizedBox(height: 8),
            Text(
              'of ${formatCurrency(totalIncome)} income',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 22),
            _BudgetProgressBar(progress: usedPct),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${formatPercent(usedPercent)} used',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.expense,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${formatCurrency(remaining)} left',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ] else if (!trackInwardFlow) ...[
            const SizedBox(height: 8),
            Text(
              'This month',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BudgetProgressBar extends StatelessWidget {
  const _BudgetProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: SizedBox(
        height: 6,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: AppColors.surfaceHigh),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.0, 1.0),
              child: const DecoratedBox(
                decoration: BoxDecoration(color: AppColors.ui),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatMiniCard extends StatelessWidget {
  const StatMiniCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.subtitle,
    this.subtitleColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final String? subtitle;
  final Color? subtitleColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassContainer(
      radius: AppRadius.lg,
      blur: 10,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: 17, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: subtitleColor ?? AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
