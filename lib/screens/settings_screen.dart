import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/brand.dart';
import '../core/theme/app_decorations.dart';
import '../widgets/glass_container.dart';
import '../widgets/settings_tour_overlay.dart';
import '../core/theme/app_spacing.dart';
import '../core/utils/formatters.dart';
import '../features/backup/backup_service.dart';
import '../features/ingest/ingest_service.dart';
import '../providers/app_preferences.dart';
import '../providers/category_catalog.dart';
import 'about_screen.dart';
import 'categories_screen.dart';
import 'month_end_screen.dart';

Future<void> _editMonthlyIncome(
  BuildContext context,
  AppPreferences prefs,
) async {
  final controller = TextEditingController(
    text: prefs.hasMonthlyIncome
        ? formatAmountInput(prefs.monthlyIncome)
        : '',
  );

  final value = await showDialog<double>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppColors.backgroundElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text('Monthly income'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Used as your income baseline for budget and savings.',
              style: Theme.of(
                dialogContext,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [CommaThousandsInputFormatter()],
              decoration: const InputDecoration(
                prefixText: 'Rs ',
                hintText: '0',
              ),
            ),
          ],
        ),
        actions: [
          if (prefs.hasMonthlyIncome)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 0.0),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textMuted,
              ),
              child: const Text('Clear'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = parseAmountInput(controller.text);
              Navigator.pop(dialogContext, parsed ?? prefs.monthlyIncome);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.ui,
              foregroundColor: AppColors.textOnPrimary,
            ),
            child: const Text('Save'),
          ),
        ],
      );
    },
  );

  if (value != null) {
    await prefs.setMonthlyIncome(value);
  }
}

Future<void> _editAccountHolderName(
  BuildContext context,
  AppPreferences prefs,
) async {
  final controller = TextEditingController(text: prefs.accountHolderName);

  final value = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppColors.backgroundElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text('Your name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transfers to or from this name go to Inbox for you to confirm '
              'instead of auto-counting as spend or income.',
              style: Theme.of(
                dialogContext,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Muhammad Arham Babar',
              ),
            ),
          ],
        ),
        actions: [
          if (prefs.hasAccountHolderName)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, ''),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textMuted,
              ),
              child: const Text('Clear'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.ui,
              foregroundColor: AppColors.textOnPrimary,
            ),
            child: const Text('Save'),
          ),
        ],
      );
    },
  );

  if (value != null) {
    await prefs.setAccountHolderName(value);
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _scrollController = ScrollController();
  final _dataSourcesKey = GlobalKey();
  final _backupKey = GlobalKey();
  final _reportsKey = GlobalKey();
  final _cashFlowKey = GlobalKey();
  final _aboutKey = GlobalKey();

  bool _showTour = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final prefs = context.read<AppPreferences>();
      if (!prefs.hasSeenSettingsTour) {
        setState(() => _showTour = true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<SettingsTourStep> _tourSteps() => [
        SettingsTourStep(
          targetKey: _dataSourcesKey,
          title: 'Data sources',
          body:
              'Connect app notifications, SMS, and Gmail here. '
              'This is how HISAAB auto-captures your payments.',
          icon: Icons.notifications_active_outlined,
        ),
        SettingsTourStep(
          targetKey: _backupKey,
          title: 'Backup',
          body: 'Export all your transactions to a file anytime — '
              'everything stays on your device until you share it.',
          icon: Icons.ios_share_rounded,
        ),
        SettingsTourStep(
          targetKey: _reportsKey,
          title: 'Reports',
          body: 'Open month-end breakdowns, category trends, and CSV export '
              'when you want a full picture of the month.',
          icon: Icons.pie_chart_outline_rounded,
        ),
        SettingsTourStep(
          targetKey: _cashFlowKey,
          title: 'Cash flow',
          body:
              'Income budget is off by default. Turn on "Show income budget" '
              'when you want savings tracking — or enable cash received to '
              'log money in.',
          icon: Icons.account_balance_wallet_outlined,
        ),
        SettingsTourStep(
          targetKey: _aboutKey,
          title: 'About & privacy',
          body: 'App info and our privacy promise — '
              'your data never leaves your phone unless you export it.',
          icon: Icons.info_outline_rounded,
        ),
      ];

  Future<void> _completeTour() async {
    await context.read<AppPreferences>().markSettingsTourSeen();
    if (mounted) setState(() => _showTour = false);
  }

  Future<void> _exportBackup(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    final result = await context.read<BackupService>().exportToFile();
    if (!context.mounted) return;
    messenger.clearSnackBars();
    if (!result.isSuccess) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Export failed'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppBackground(),
          Consumer2<IngestService, AppPreferences>(
            builder: (context, ingest, prefs, _) {
              return SafeArea(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.pageH,
                    4,
                    AppSpacing.pageH,
                    _showTour ? 268 : 32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                            color: AppColors.textSecondary,
                          ),
                          const AppAccentBar(height: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Settings',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(letterSpacing: -0.3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.section),
                KeyedSubtree(
                  key: _dataSourcesKey,
                  child: _SettingsGroup(
                  title: 'Data Sources',
                  children: [
                    _SettingsTile(
                      icon: Icons.notifications_active_outlined,
                      title: 'App Notifications',
                      subtitle: Platform.isAndroid
                          ? (ingest.hasNotificationAccessGranted
                              ? 'Reading bank & UPI app alerts'
                              : 'Tap to grant notification access')
                          : 'Not available on iOS',
                      trailing: _StatusPill(
                        enabled: Platform.isAndroid &&
                            ingest.hasNotificationAccessGranted,
                        label: Platform.isAndroid ? null : 'N/A',
                      ),
                      onTap: Platform.isAndroid
                          ? () async {
                              await ingest.openNotificationSettings();
                              await ingest.refreshNotificationAccess();
                            }
                          : null,
                    ),
                    if (Platform.isAndroid && ingest.hasNotificationAccessGranted)
                      _SettingsTile(
                        icon: Icons.battery_charging_full_rounded,
                        title: 'Background monitoring',
                        subtitle: ingest.isBatteryUnrestricted
                            ? 'Battery unrestricted — best capture reliability'
                            : 'Tap to disable battery limits for HISAAB',
                        trailing: _StatusPill(
                          enabled: ingest.isBatteryUnrestricted,
                          label: ingest.isBatteryUnrestricted ? 'On' : 'Fix',
                        ),
                        onTap: () async {
                          await ingest.requestBatteryOptimizationExemption();
                          await ingest.refreshBatteryOptimization();
                        },
                      ),
                    _SettingsTile(
                      icon: Icons.sms_outlined,
                      title: 'SMS Alerts',
                      subtitle: Platform.isAndroid
                          ? 'Auto-read transaction SMS'
                          : 'Use Shortcuts — see docs/IOS_SHORTCUTS.md',
                      trailing: _StatusPill(enabled: Platform.isAndroid),
                      onTap: Platform.isAndroid
                          ? () => Permission.sms.request()
                          : null,
                    ),
                    _SettingsTile(
                      icon: Icons.mail_outline,
                      title: 'Gmail',
                      subtitle: ingest.isGmailConnected
                          ? 'Connected — tap to sync'
                          : 'Connect to sync email alerts',
                      trailing: _StatusPill(
                        enabled: ingest.isGmailConnected,
                        label: ingest.isGmailConnected ? 'On' : 'Connect',
                      ),
                      onTap: () async {
                        if (ingest.isGmailConnected) {
                          final messenger = ScaffoldMessenger.of(context);
                          messenger.clearSnackBars();
                          final count = await ingest.syncGmail();
                          if (!context.mounted) return;
                          messenger.clearSnackBars();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Synced $count email alerts'),
                            ),
                          );
                        } else {
                          await ingest.connectGmail();
                        }
                      },
                    ),
                    if (ingest.isGmailConnected)
                      _SettingsTile(
                        icon: Icons.logout_rounded,
                        title: 'Disconnect Gmail',
                        subtitle: 'Remove Gmail access',
                        onTap: () => ingest.disconnectGmail(),
                      ),
                  ],
                ),
                ),
                const SizedBox(height: AppSpacing.section),
                KeyedSubtree(
                  key: _backupKey,
                  child: _SettingsGroup(
                  title: 'Backup',
                  children: [
                    _SettingsTile(
                      icon: Icons.ios_share_rounded,
                      title: 'Export backup',
                      subtitle: 'Save all transactions to a text file',
                      onTap: () => _exportBackup(context),
                    ),
                  ],
                ),
                ),
                const SizedBox(height: AppSpacing.section),
                KeyedSubtree(
                  key: _reportsKey,
                  child: _SettingsGroup(
                  title: 'Reports',
                  children: [
                    _SettingsTile(
                      icon: Icons.pie_chart_outline_rounded,
                      title: 'Month-end report',
                      subtitle: 'Spending breakdown, trends & CSV export',
                      onTap: () => MonthEndScreen.open(context),
                    ),
                  ],
                ),
                ),
                const SizedBox(height: AppSpacing.section),
                KeyedSubtree(
                  key: _cashFlowKey,
                  child: const _CashFlowSettingsGroup(),
                ),
                const SizedBox(height: AppSpacing.section),
                KeyedSubtree(
                  key: _aboutKey,
                  child: _SettingsGroup(
                  title: 'About',
                  children: [
                    _SettingsTile(
                      icon: Icons.info_outline_rounded,
                      title: 'About ${AppBrand.name}',
                      subtitle: 'Made by Arham · Vawcom AI agency',
                      onTap: () => AboutScreen.open(context),
                    ),
                    const _SettingsTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy',
                      subtitle: 'All data stays on your device',
                    ),
                  ],
                ),
                ),
              ],
            ),
          ),
        );
      },
    ),
          if (_showTour)
            SettingsTourOverlay(
              steps: _tourSteps(),
              scrollController: _scrollController,
              onComplete: _completeTour,
            ),
        ],
      ),
    );
  }
}

class _CashFlowSettingsGroup extends StatelessWidget {
  const _CashFlowSettingsGroup();

  @override
  Widget build(BuildContext context) {
    return Selector<AppPreferences, bool>(
      selector: (_, prefs) => prefs.showIncome,
      builder: (context, showIncome, _) {
        return _SettingsGroup(
          title: 'Cash flow',
          children: [
            Selector<AppPreferences, bool>(
              selector: (_, prefs) => prefs.trackInwardFlow,
              builder: (context, trackInwardFlow, _) {
                return _SettingsSwitchTile(
                  icon: Icons.south_west_rounded,
                  title: 'Track cash received',
                  subtitle: trackInwardFlow
                      ? 'Logging money in — SMS, alerts & manual'
                      : 'Spending only — turn on to track cash in',
                  value: trackInwardFlow,
                  onChanged:
                      context.read<AppPreferences>().setTrackInwardFlow,
                );
              },
            ),
            Selector<AppPreferences, String>(
              selector: (_, prefs) => prefs.accountHolderName,
              builder: (context, accountHolderName, _) {
                return _SettingsTile(
                  icon: Icons.person_outline_rounded,
                  title: 'Your name',
                  subtitle: accountHolderName.isNotEmpty
                      ? accountHolderName
                      : 'Self-transfers involving your name go to Inbox',
                  onTap: () => _editAccountHolderName(
                    context,
                    context.read<AppPreferences>(),
                  ),
                );
              },
            ),
            Selector<AppPreferences, bool>(
              selector: (_, prefs) => prefs.showIncome,
              builder: (context, showIncome, _) {
                return _SettingsSwitchTile(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Show income budget',
                  subtitle: showIncome
                      ? 'Monthly income & savings on Home & Report'
                      : 'Hidden — spending (and cash in, if enabled) only',
                  value: showIncome,
                  onChanged: context.read<AppPreferences>().setShowIncome,
                );
              },
            ),
            if (showIncome)
              Selector<AppPreferences, (bool, double)>(
                selector: (_, prefs) =>
                    (prefs.hasMonthlyIncome, prefs.monthlyIncome),
                builder: (context, data, _) {
                  final (hasIncome, income) = data;
                  return _SettingsTile(
                    icon: Icons.payments_outlined,
                    title: 'Monthly income',
                    subtitle: hasIncome
                        ? formatCurrency(income)
                        : 'Tap to set your monthly income',
                    trailing: hasIncome
                        ? Text(
                            formatCompactCurrency(income),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AppColors.income,
                                  fontWeight: FontWeight.w700,
                                ),
                          )
                        : null,
                    onTap: () => _editMonthlyIncome(
                      context,
                      context.read<AppPreferences>(),
                    ),
                  );
                },
              ),
            Selector<CategoryCatalog, int>(
              selector: (_, catalog) => catalog.customCount,
              builder: (context, customCount, _) {
                return _SettingsTile(
                  icon: Icons.category_outlined,
                  title: 'Categories',
                  subtitle: customCount == 0
                      ? 'Food, Transport, Bills, and more'
                      : '$customCount custom · tap to manage',
                  onTap: () => CategoriesScreen.open(context),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Row(
            children: [
              const AppAccentBar(height: 16),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.textMuted,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        GlassCard(
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  const Divider(
                    height: 1,
                    indent: 66,
                    endIndent: 16,
                    color: AppColors.border,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: AppDecorations.iconBadge(AppColors.ui),
                child: Icon(icon, color: AppColors.ui, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ] else if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textDim,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: AppDecorations.iconBadge(AppColors.ui),
              child: Icon(icon, color: AppColors.ui, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  SizedBox(
                    height: 34,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                        layoutBuilder: (current, previous) {
                          return Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              ...previous,
                              if (current != null) current,
                            ],
                          );
                        },
                        child: Text(
                          subtitle,
                          key: ValueKey(subtitle),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _SmoothToggle(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _SmoothToggle extends StatefulWidget {
  const _SmoothToggle({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  State<_SmoothToggle> createState() => _SmoothToggleState();
}

class _SmoothToggleState extends State<_SmoothToggle> {
  late bool _on;

  @override
  void initState() {
    super.initState();
    _on = widget.value;
  }

  @override
  void didUpdateWidget(_SmoothToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _on = widget.value;
    }
  }

  void _handleTap() {
    final next = !_on;
    setState(() => _on = next);
    HapticFeedback.selectionClick();
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: _on,
      button: true,
      label: _on ? 'On' : 'Off',
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOutCubic,
          width: 48,
          height: 28,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            color: _on
                ? AppColors.ui.withValues(alpha: 0.28)
                : AppColors.glassFill,
            border: Border.all(
              color: _on
                  ? AppColors.ui.withValues(alpha: 0.45)
                  : AppColors.glassBorder,
              width: 1,
            ),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOutCubic,
            alignment: _on ? Alignment.centerRight : Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOutCubic,
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _on ? AppColors.ui : AppColors.textMuted,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.enabled, this.label});

  final bool enabled;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final text = label ?? (enabled ? 'On' : 'Off');
    final color = enabled ? AppColors.accent : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.borderXs,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
