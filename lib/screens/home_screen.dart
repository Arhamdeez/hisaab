import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/brand.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart' show AppRadius;
import '../core/utils/app_refresh.dart';
import '../core/utils/formatters.dart';
import '../navigation/shell_scope.dart';
import '../providers/app_preferences.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction.dart';
import '../widgets/glass_container.dart';
import '../widgets/centered_content.dart';
import '../widgets/spend_focus_hero.dart';
import '../widgets/balance_hero_card.dart' show StatMiniCard;
import '../widgets/home_sections.dart' show HomeRecentActivity;
import '../widgets/glass_bottom_nav_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<TransactionProvider, AppPreferences>(
      builder: (context, provider, prefs, _) {
        final month = provider.selectedMonth;
        final summary = provider.summaryForMonth(month);
        // Manual monthly income (Settings) takes precedence; otherwise fall
        // back to income derived from credit transactions.
        final income = prefs.hasMonthlyIncome
            ? prefs.monthlyIncome
            : summary.totalCredit;

        final recent = provider.transactionsForMonth(month).take(5).toList();
        final activeDays = summary.dailySpending.where((d) => d > 0).length;
        final dailyAvg = summary.totalDebit / (activeDays == 0 ? 1 : activeDays);
        CategorySummary? topCategory;
        for (final c in summary.byCategory) {
          if (topCategory == null || c.total > topCategory.total) {
            topCategory = c;
          }
        }
        final hasActivity = summary.transactionCount > 0;

        return SafeArea(
          child: AppRefreshScroll(
            child: CustomScrollView(
              physics: refreshScrollPhysics,
              slivers: [
                SliverToBoxAdapter(
                  child: CenteredContent(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _BrandHeader(pendingCount: summary.pendingCount),
                        const SizedBox(height: 20),
                        _MonthSelector(month: month),
                        const SizedBox(height: 20),
                        SpendFocusHero(
                          totalSpent: summary.totalDebit,
                          income: income,
                          showIncome: prefs.showIncome,
                          monthLabel: formatMonthYear(month),
                          transactionCount: summary.transactionCount,
                        ),
                        if (summary.pendingCount > 0) ...[
                          const SizedBox(height: 16),
                          _PendingBanner(count: summary.pendingCount),
                        ],
                      ],
                    ),
                  ),
                ),
                if (hasActivity)
                  SliverToBoxAdapter(
                    child: CenteredContent(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: StatMiniCard(
                                label: 'Daily avg',
                                value: formatCompactCurrency(dailyAvg),
                                icon: Icons.trending_up_rounded,
                                iconColor: AppColors.primary,
                                subtitle:
                                    '$activeDays active ${activeDays == 1 ? 'day' : 'days'}',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: topCategory != null
                                  ? StatMiniCard(
                                      label: 'Top category',
                                      value: formatCompactCurrency(
                                        topCategory.total,
                                      ),
                                      icon: topCategory.category.icon,
                                      iconColor: topCategory.category.color,
                                      subtitle: topCategory.category.label,
                                    )
                                  : const StatMiniCard(
                                      label: 'Top category',
                                      value: '—',
                                      icon: Icons.category_outlined,
                                      iconColor: AppColors.textMuted,
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: CenteredContent(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: HomeRecentActivity(
                      transactions: recent,
                      onViewAll: () => ShellScope.goToTransactions(context),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: GlassBottomNavBar.reservedHeight(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.pendingCount});

  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CASH FLOW',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textDim,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            RichText(
              text: TextSpan(
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  height: 1,
                  color: AppColors.textPrimary,
                ),
                children: const [
                  TextSpan(text: AppBrand.name),
                  TextSpan(
                    text: '.',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const Spacer(),
            _HeaderIconButton(
              icon: Icons.notifications_none_rounded,
              showBadge: pendingCount > 0,
              onTap: () => ShellScope.goToInbox(context),
            ),
            const SizedBox(width: 10),
            _HeaderIconButton(
              icon: Icons.settings_outlined,
              onTap: () => ShellScope.goToSettings(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    this.showBadge = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GlassContainer(
              radius: 22,
              blur: 12,
              padding: EdgeInsets.zero,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(icon, color: AppColors.textSecondary, size: 22),
              ),
            ),
            if (showBadge)
              Positioned(
                top: 10,
                right: 11,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        final theme = Theme.of(context);
        return SizedBox(
          width: double.infinity,
          child: GlassContainer(
            radius: AppRadius.lg,
            blur: 10,
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
            child: Row(
            children: [
              _NavCircle(
                icon: Icons.chevron_left_rounded,
                onTap: () => _shiftMonth(provider, -1),
              ),
              Expanded(
                child: Text(
                  formatMonthYear(month),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                ),
              ),
              _NavCircle(
                icon: Icons.chevron_right_rounded,
                onTap: () => _shiftMonth(provider, 1),
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  void _shiftMonth(TransactionProvider provider, int delta) {
    final current = provider.selectedMonth;
    final next = DateTime(current.year, current.month + delta);
    if (next.isAfter(DateTime.now())) return;
    provider.setSelectedMonth(next);
  }
}

class _NavCircle extends StatelessWidget {
  const _NavCircle({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.glassFillStrong,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Icon(icon, color: AppColors.textSecondary, size: 22),
      ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => ShellScope.goToInbox(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.inbox_outlined,
                  color: AppColors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  '$count transaction${count == 1 ? '' : 's'} need review',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.warning,
                      ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.warning),
            ],
          ),
        ),
      ),
    );
  }
}
