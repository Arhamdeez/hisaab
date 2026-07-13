import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/brand.dart';
import '../../core/theme/app_colors.dart';
import 'ingest_bridge.dart';
import 'ingest_service.dart';

/// Opens notification access settings and shows OEM-specific guidance on failure.
abstract final class NotificationAccess {
  static Future<NotificationAccessOpenResult> openSettings() async {
    if (!Platform.isAndroid) {
      return const NotificationAccessOpenResult(opened: false);
    }
    return IngestBridge.instance.openNotificationAccessSettings();
  }

  static Future<void> requestFromSettings(BuildContext context) async {
    await _openAndGuide(context, refreshAfter: true);
  }

  static Future<void> requestFromOnboarding(BuildContext context) async {
    await _openAndGuide(context, refreshAfter: true);
  }

  static Future<void> _openAndGuide(
    BuildContext context, {
    required bool refreshAfter,
  }) async {
    HapticFeedback.lightImpact();
    final ingest = context.read<IngestService>();
    final result = await openSettings();

    if (refreshAfter) {
      await ingest.refreshNotificationAccess();
    }

    if (!context.mounted) return;

    if (result.opened) return;

    await showManualGuide(context, result: result);
  }

  static Future<void> showManualGuide(
    BuildContext context, {
    NotificationAccessOpenResult? result,
  }) async {
    final manufacturer = (result?.manufacturer ?? '').toLowerCase();
    final steps = _manualSteps(manufacturer);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final bottom = MediaQuery.viewInsetsOf(ctx).bottom;

        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Material(
            color: const Color(0xFF1A1010),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Enable notification access',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Could not open settings automatically on this device. '
                      'Follow these steps, then turn on ${AppBrand.name}:',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...steps.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.ui.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${entry.key + 1}',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ui,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        final retry = await openSettings();
                        if (!context.mounted) return;
                        if (!retry.opened) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Still could not open automatically — use the steps above.',
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('Try opening settings again'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static List<String> manualStepsFor(String manufacturer) =>
      _manualSteps(manufacturer.toLowerCase());

  static List<String> _manualSteps(String manufacturer) {
    if (manufacturer.contains('samsung')) {
      return [
        'Open Settings',
        'Tap Security and privacy',
        'Tap More security settings',
        'Tap Notification access (or Special access → Notification access)',
        'Find ${AppBrand.name} and turn it ON',
      ];
    }
    if (manufacturer.contains('xiaomi') ||
        manufacturer.contains('redmi') ||
        manufacturer.contains('poco')) {
      return [
        'Open Settings',
        'Tap Apps → Manage apps',
        'Tap the ⋮ menu → Special permissions',
        'Tap Notification access',
        'Find ${AppBrand.name} and turn it ON',
      ];
    }
    if (manufacturer.contains('oppo') || manufacturer.contains('realme')) {
      return [
        'Open Settings',
        'Tap Privacy → Permission manager',
        'Tap Special app access → Notification access',
        'Find ${AppBrand.name} and turn it ON',
      ];
    }
    if (manufacturer.contains('oneplus')) {
      return [
        'Open Settings',
        'Tap Apps → Special app access',
        'Tap Notification access',
        'Find ${AppBrand.name} and turn it ON',
      ];
    }
    if (manufacturer.contains('huawei') || manufacturer.contains('honor')) {
      return [
        'Open Settings',
        'Tap Apps → Apps',
        'Tap Special access → Notification access',
        'Find ${AppBrand.name} and turn it ON',
      ];
    }
    return [
      'Open Settings',
      'Tap Apps (or Apps & notifications)',
      'Tap Special app access (or Advanced → Special app access)',
      'Tap Notification access',
      'Find ${AppBrand.name} and turn it ON',
    ];
  }
}
