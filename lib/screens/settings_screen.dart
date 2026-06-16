import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_decorations.dart';
import '../widgets/glass_container.dart';
import '../core/theme/app_spacing.dart';
import '../core/utils/formatters.dart';
import '../features/backup/backup_service.dart';
import '../features/ingest/ingest_service.dart';
import '../providers/app_preferences.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _exportBackup(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await context.read<BackupService>().exportToFile();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.isSuccess
              ? 'Exported ${result.count} transactions'
              : result.message ?? 'Export failed',
        ),
      ),
    );
  }

  Future<void> _editMonthlyIncome(
    BuildContext context,
    AppPreferences prefs,
  ) async {
    final controller = TextEditingController(
      text: prefs.hasMonthlyIncome
          ? prefs.monthlyIncome.toStringAsFixed(0)
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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
                final parsed = double.tryParse(
                  controller.text.replaceAll(',', '').trim(),
                );
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

  @override
  Widget build(BuildContext context) {
    return Consumer2<IngestService, AppPreferences>(
      builder: (context, ingest, prefs, _) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: AppSpacing.page,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppAccentBar(height: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Settings',
                        style: Theme.of(context)
                            .textTheme
                            .headlineLarge
                            ?.copyWith(letterSpacing: -0.4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.section),
                _SettingsGroup(
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
                          ? () => ingest.openNotificationSettings()
                          : null,
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
                          final count = await ingest.syncGmail();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
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
                const SizedBox(height: AppSpacing.section),
                _SettingsGroup(
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
                const SizedBox(height: AppSpacing.section),
                _SettingsGroup(
                  title: 'Cash flow',
                  children: [
                    _SettingsSwitchTile(
                      icon: Icons.south_west_rounded,
                      title: 'Track cash received',
                      subtitle: prefs.trackInwardFlow
                          ? 'Logging money in — SMS, alerts & manual'
                          : 'Spending only — turn on to track cash in',
                      value: prefs.trackInwardFlow,
                      onChanged: prefs.setTrackInwardFlow,
                    ),
                    _SettingsSwitchTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Show income budget',
                      subtitle: prefs.showIncome
                          ? 'Monthly income & savings on Home & Report'
                          : 'Hidden — spending (and cash in, if enabled) only',
                      value: prefs.showIncome,
                      onChanged: prefs.setShowIncome,
                    ),
                    if (prefs.showIncome)
                      _SettingsTile(
                        icon: Icons.payments_outlined,
                        title: 'Monthly income',
                        subtitle: prefs.hasMonthlyIncome
                            ? formatCurrency(prefs.monthlyIncome)
                            : 'Tap to set your monthly income',
                        trailing: prefs.hasMonthlyIncome
                            ? Text(
                                formatCompactCurrency(prefs.monthlyIncome),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: AppColors.income,
                                      fontWeight: FontWeight.w700,
                                    ),
                              )
                            : null,
                        onTap: () => _editMonthlyIncome(context, prefs),
                      ),
                    const _SettingsTile(
                      icon: Icons.category_outlined,
                      title: 'Categories',
                      subtitle: 'Food, Transport, Bills, and more',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.section),
                _SettingsGroup(
                  title: 'About',
                  children: const [
                    _SettingsTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy',
                      subtitle: 'All data stays on your device',
                    ),
                  ],
                ),
              ],
            ),
          ),
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
    return Padding(
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
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.ui.withValues(alpha: 0.5),
            activeThumbColor: AppColors.ui,
          ),
        ],
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
