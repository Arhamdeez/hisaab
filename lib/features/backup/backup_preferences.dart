import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/data/local_data_persistence.dart';
import '../../providers/app_preferences.dart';
import '../../providers/category_catalog.dart';

/// Preference snapshot stored inside a backup database.
///
/// Transactions already live in the SQLite file. Income, categories, and the
/// account-holder name live in SharedPreferences, so they are copied into
/// [storageKey] on the backup file and written back on restore.
abstract final class BackupPreferences {
  static const storageKey = 'hisaab_backup_prefs_v1';

  static const keys = <String>[
    ...AppPreferences.persistedBackupKeys,
    CategoryCatalog.storageKey,
    LocalDataPersistence.onboardingCompleteKey,
  ];

  static String encode(SharedPreferences prefs) {
    final values = <String, Object?>{};
    for (final key in keys) {
      if (!prefs.containsKey(key)) continue;
      values[key] = prefs.get(key);
    }
    return jsonEncode(values);
  }

  /// Writes [raw] onto [prefs]. A restore always marks onboarding complete so
  /// the saved history is what the user sees after a fresh install.
  static Future<void> apply(SharedPreferences prefs, String? raw) async {
    final values = <String, Object?>{};
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        for (final entry in decoded.entries) {
          values[entry.key.toString()] = entry.value;
        }
      }
    }

    for (final key in keys) {
      if (key == LocalDataPersistence.onboardingCompleteKey) continue;
      if (!values.containsKey(key)) {
        await prefs.remove(key);
        continue;
      }
      final value = values[key];
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      } else if (value is num && key == AppPreferences.monthlyIncomeKey) {
        await prefs.setDouble(key, value.toDouble());
      }
    }
    await prefs.setBool(LocalDataPersistence.onboardingCompleteKey, true);
  }
}
