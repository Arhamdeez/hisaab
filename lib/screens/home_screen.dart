import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/brand.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_decorations.dart';
import '../core/theme/app_spacing.dart' show AppRadius;
import '../core/utils/app_refresh.dart';
import '../core/utils/formatters.dart';
import '../navigation/shell_scope.dart';
import '../providers/app_preferences.dart';
import '../providers/transaction_provider.dart';
import '../widgets/app_logo_mark.dart';
import '../widgets/glass_container.dart';
import '../widgets/centered_content.dart';
import '../widgets/spend_focus_hero.dart';
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
        // Pending items are reviewed globally (the Inbox shows every month), so
        // the bell badge and banner track the total, not just this month's.
        final pendingTotal = provider.pendingCount;
        // Income budget uses [showIncome] only — independent of cash-in tracking.
        final income = prefs.resolveIncome(summary);

        // Show the most recently-dated activity first.
        final recent = provider.recentForMonth(month);

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
                        _BrandHeader(pendingCount: pendingTotal),
                        const SizedBox(height: 20),
                        _MonthSelector(month: month),
                        const SizedBox(height: 20),
                        SpendFocusHero(
                          totalSpent: summary.totalDebit,
                          income: income,
                          showIncome: prefs.showIncome,
                          trackInwardFlow: prefs.trackInwardFlow,
                          totalReceived: summary.totalCredit,
                          monthLabel: formatMonthYear(month),
                          transactionCount: summary.transactionCount,
                        ),
                        if (pendingTotal > 0) ...[
                          const SizedBox(height: 16),
                          _PendingBanner(count: pendingTotal),
                        ],
                      ],
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
        Row(
          children: [
            const AppLogoMark(size: 16, color: AppColors.brand),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: AppDecorations.pillChip(),
              child: Text(
                'CASH FLOW',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
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
                    style: TextStyle(color: AppColors.brand),
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
              radius: AppRadius.iconButton,
              blur: 12,
              padding: EdgeInsets.zero,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(icon, color: AppColors.textPrimary, size: 22),
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
                    color: AppColors.brand,
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
            blur: 12,
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
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    shadows: [
                      Shadow(
                        color: AppColors.ui.withValues(alpha: 0.15),
                        blurRadius: 12,
                      ),
                    ],
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
        decoration: AppDecorations.iconButton(),
        child: Icon(icon, color: AppColors.textPrimary, size: 22),
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
            borderRadius: BorderRadius.circular(AppRadius.lg),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.warning.withValues(alpha: 0.16),
                AppColors.warning.withValues(alpha: 0.06),
              ],
            ),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: AppColors.warning.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
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
