import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../widgets/glass_container.dart';
import '../core/utils/formatters.dart';

class SpendingTrendChart extends StatelessWidget {
  const SpendingTrendChart({
    super.key,
    required this.monthlyTotals,
    required this.monthLabels,
  });

  final List<double> monthlyTotals;
  final List<String> monthLabels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxY = monthlyTotals.fold<double>(0, (m, v) => v > m ? v : m);
    final chartMax = maxY > 0 ? maxY * 1.15 : 1000.0;

    return GlassContainer(
      radius: AppRadius.xl,
      enableBlur: false,
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spending trend',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 2),
          Text(
            'Last ${monthLabels.length} months',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: chartMax,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: chartMax / 3,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.border.withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= monthLabels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            monthLabels[i],
                            style: theme.textTheme.bodySmall,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      monthlyTotals.length,
                      (i) => FlSpot(i.toDouble(), monthlyTotals[i]),
                    ),
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: AppColors.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                        radius: 4,
                        color: AppColors.primary,
                        strokeWidth: 2,
                        strokeColor: AppColors.background,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.25),
                          AppColors.primary.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Weekly spending bars for the month: each week is a labelled bar sitting in a
/// full-height track, with its total printed above — clean and readable instead
/// of ~30 thin daily bars.
class CashFlowChart extends StatelessWidget {
  const CashFlowChart({
    super.key,
    required this.dailySpending,
    required this.totalExpense,
    required this.month,
  });

  final List<double> dailySpending;
  final double totalExpense;

  /// The month being reported, used to trim unfilled future days so the current
  /// month isn't shown tapering off into empty bars.
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // For the current month, only count days up to today.
    final now = DateTime.now();
    final isCurrentMonth = month.year == now.year && month.month == now.month;
    final totalDays = dailySpending.length;
    final daysToShow =
        isCurrentMonth ? now.day.clamp(1, totalDays) : totalDays;
    final data = dailySpending.take(daysToShow).toList();

    // Bucket the days into calendar weeks (1–7, 8–14, …).
    final weeks = <({String label, double total})>[];
    for (var start = 0; start < data.length; start += 7) {
      final end = math.min(start + 7, data.length);
      var sum = 0.0;
      for (var i = start; i < end; i++) {
        sum += data[i];
      }
      weeks.add((label: '${start + 1}–$end', total: sum));
    }

    final maxWeek = weeks.fold<double>(0, (m, w) => w.total > m ? w.total : m);
    final niceMax = _niceCeil(maxWeek);
    final hasData = totalExpense > 0 && weeks.isNotEmpty;

    return GlassContainer(
      radius: AppRadius.xl,
      enableBlur: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spending by week', style: theme.textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(
            formatCurrency(totalExpense),
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 180,
            child: hasData
                ? BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: niceMax,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: niceMax / 4,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: AppColors.border.withValues(alpha: 0.45),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 42,
                            interval: niceMax / 4,
                            getTitlesWidget: (value, meta) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  formatCompactCurrency(value),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.textMuted,
                                    fontSize: 10,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i < 0 || i >= weeks.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  weeks[i].label,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      // Persistent value labels above each bar.
                      barTouchData: BarTouchData(
                        enabled: false,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => Colors.transparent,
                          tooltipPadding: EdgeInsets.zero,
                          tooltipMargin: 6,
                          fitInsideVertically: true,
                          getTooltipItem: (group, _, rod, _) {
                            if (rod.toY <= 0) {
                              return null;
                            }
                            return BarTooltipItem(
                              formatCompactCurrency(rod.toY),
                              theme.textTheme.bodySmall!.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            );
                          },
                        ),
                      ),
                      barGroups: List.generate(weeks.length, (i) {
                        return BarChartGroupData(
                          x: i,
                          showingTooltipIndicators: const [0],
                          barRods: [
                            BarChartRodData(
                              toY: weeks[i].total,
                              width: weeks.length > 4 ? 26 : 34,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: niceMax,
                                color: AppColors.primary.withValues(alpha: 0.08),
                              ),
                              gradient: const LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  AppColors.primaryDim,
                                  AppColors.primary,
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  )
                : const Center(
                    child: Text(
                      'No spending yet this month',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Rounds [value] up to a clean axis maximum (e.g. 170 → 180, 1240 → 1500).
  static double _niceCeil(double value) {
    if (value <= 0) return 100;
    final magnitude =
        math.pow(10, (math.log(value) / math.ln10).floor()).toDouble();
    final normalized = value / magnitude; // 1.0 .. 9.99
    final double nice;
    if (normalized <= 1) {
      nice = 1;
    } else if (normalized <= 1.5) {
      nice = 1.5;
    } else if (normalized <= 2) {
      nice = 2;
    } else if (normalized <= 3) {
      nice = 3;
    } else if (normalized <= 4) {
      nice = 4;
    } else if (normalized <= 5) {
      nice = 5;
    } else if (normalized <= 8) {
      nice = 8;
    } else {
      nice = 10;
    }
    return nice * magnitude;
  }
}

class CategoryDonutChart extends StatelessWidget {
  const CategoryDonutChart({
    super.key,
    required this.summaries,
    required this.total,
  });

  final List<({String label, double value, Color color})> summaries;
  final double total;

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'No spending data',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    return SizedBox(
      height: 180,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 52,
          sections: summaries.map((s) {
            final pct = total > 0 ? (s.value / total) * 100 : 0.0;
            return PieChartSectionData(
              value: s.value,
              color: s.color,
              radius: 32,
              title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
              titleStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.linen,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
