import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/brand.dart';
import '../core/motion.dart';
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.netBalanceToggleKey,
    required this.scrollController,
    this.onHeroIntroComplete,
  });

  final GlobalKey netBalanceToggleKey;
  final ScrollController scrollController;
  final VoidCallback? onHeroIntroComplete;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer2<TransactionProvider, AppPreferences>(
      builder: (context, provider, prefs, _) {
        final month = provider.selectedMonth;
        final summary = provider.summaryForMonth(month);
        final pendingTotal = provider.pendingCount;
        final income = prefs.resolveIncome(summary, month);
        final recent = provider.recentForMonth(month);

        return SafeArea(
          child: AppRefreshScroll(
            child: CustomScrollView(
              controller: widget.scrollController,
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
                              netBalanceToggleKey: widget.netBalanceToggleKey,
                              onHeroIntroComplete: widget.onHeroIntroComplete,
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
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _pickMonth(context, provider),
                    child: AppMotion.softSwap(
                      key: ValueKey('${month.year}-${month.month}'),
                      duration: AppMotion.fast,
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
    HapticFeedback.selectionClick();
    provider.setSelectedMonth(next);
  }

  Future<void> _pickMonth(
    BuildContext context,
    TransactionProvider provider,
  ) async {
    HapticFeedback.selectionClick();
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      isScrollControlled: true,
      builder: (_) => _MonthPickerSheet(selected: provider.selectedMonth),
    );
    if (picked != null) {
      HapticFeedback.selectionClick();
      provider.setSelectedMonth(picked);
    }
  }
}

/// Bottom sheet to jump to any month up to the current one.
class _MonthPickerSheet extends StatefulWidget {
  const _MonthPickerSheet({required this.selected});

  final DateTime selected;

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  static const _monthLabels = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.selected.year;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final canGoNextYear = _year < now.year;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundElevated,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withValues(alpha: 0.5),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _YearArrow(
                    icon: Icons.chevron_left_rounded,
                    onTap: () => setState(() => _year -= 1),
                  ),
                  Expanded(
                    child: Text(
                      '$_year',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _YearArrow(
                    icon: Icons.chevron_right_rounded,
                    onTap: canGoNextYear
                        ? () => setState(() => _year += 1)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.1,
                children: List.generate(12, (index) {
                  final monthDate = DateTime(_year, index + 1);
                  final isFuture = monthDate.isAfter(DateTime(now.year, now.month));
                  final isSelected = _year == widget.selected.year &&
                      index + 1 == widget.selected.month;
                  return _MonthChip(
                    label: _monthLabels[index],
                    selected: isSelected,
                    enabled: !isFuture,
                    onTap: () => Navigator.of(context).pop(monthDate),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _YearArrow extends StatelessWidget {
  const _YearArrow({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: AppDecorations.iconButton(),
        child: Icon(
          icon,
          size: 24,
          color: disabled ? AppColors.textMuted : AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _MonthChip extends StatelessWidget {
  const _MonthChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          color: selected
              ? AppColors.ui.withValues(alpha: 0.9)
              : AppColors.glassFillStrong,
          border: Border.all(
            color: selected
                ? AppColors.ui
                : AppColors.border.withValues(alpha: 0.6),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: !enabled
                ? AppColors.textMuted.withValues(alpha: 0.5)
                : selected
                    ? AppColors.textOnPrimary
                    : AppColors.textPrimary,
          ),
        ),
      ),
    );
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
