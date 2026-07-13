import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_colors.dart';

/// Play Console use case: SMS-based money management — wallet/bank txn alerts only.
abstract final class SmsPermission {
  static const disclosureTitle = 'Allow SMS for automatic tracking';

  static const disclosureBody =
      'HISAAB reads SMS from wallet and bank short codes (such as Easypaisa 3737 '
      'and Raast 8558) to log payment alerts automatically.\n\n'
      '• Only transaction-shaped messages are processed\n'
      '• Personal chats and OTP texts are ignored\n'
      '• SMS stays on your device — nothing is uploaded\n\n'
      'SMS access is required for hands-free tracking when banks send alerts by text.';

  static Future<bool> isGranted() async {
    if (!Platform.isAndroid) return false;
    final status = await Permission.sms.status;
    return status.isGranted || status.isLimited;
  }

  /// Shows Play-compliant disclosure, then requests SMS if the user agrees.
  static Future<bool> requestForAutomation(BuildContext context) async {
    if (!Platform.isAndroid) return false;
    if (await isGranted()) return true;
    if (!context.mounted) return false;

    final agreed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(disclosureTitle),
        content: const SingleChildScrollView(
          child: Text(
            disclosureBody,
            style: TextStyle(height: 1.45, color: AppColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.ui,
              foregroundColor: AppColors.textOnPrimary,
            ),
            child: const Text('Allow SMS'),
          ),
        ],
      ),
    );
    if (agreed != true) return false;

    final status = await Permission.sms.request();
    return status.isGranted || status.isLimited;
  }
}
