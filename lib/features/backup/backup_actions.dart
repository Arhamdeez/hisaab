import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/app_preferences.dart';
import '../../providers/category_catalog.dart';
import '../../providers/transaction_provider.dart';
import 'backup_service.dart';

/// Lets the user pick a saved backup and load it into this install.
Future<BackupResult> restoreBackupInteractively(BuildContext context) async {
  final picked = await FilePicker.platform.pickFiles(
    type: FileType.any,
    allowMultiple: false,
  );
  if (picked == null || picked.files.isEmpty) {
    return const BackupResult.cancelled();
  }
  final path = picked.files.single.path;
  if (path == null || path.isEmpty) {
    return const BackupResult.failure('Could not read that file');
  }
  if (!context.mounted) return const BackupResult.cancelled();

  final result = await context.read<BackupService>().restoreFromFile(
    path,
    confirm: (count) => _confirmRestore(context, count),
  );
  if (result.isSuccess && context.mounted) {
    await AppPreferences.load();
    await CategoryCatalog.load();
    if (!context.mounted) return result;
    await context.read<TransactionProvider>().reload();
  }
  return result;
}

Future<bool> _confirmRestore(BuildContext context, int count) async {
  if (!context.mounted) return false;
  final message = count == 0
      ? 'This backup has no transactions. Transactions currently on this phone will be replaced.'
      : 'This restores $count transactions. Transactions currently on this phone will be replaced.';
  final accepted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppColors.backgroundElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text('Restore backup?'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Restore'),
          ),
        ],
      );
    },
  );
  return accepted ?? false;
}
