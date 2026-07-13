import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/transaction_repository.dart';
import '../../providers/category_catalog.dart';

/// Keeps local user data intact across app updates on the same device.
///
/// Data lives in:
/// - SQLite: `spend_tracker.sqlite` (transactions, summaries, parser rules)
/// - SharedPreferences: display prefs, custom categories, onboarding flag
/// - Native queue: `captured_ingest.db` (pending alerts, drained on launch)
///
/// Updates and `flutter run` preserve this storage unless the app is uninstalled
/// or "Clear data" is used in system settings.
abstract final class LocalDataPersistence {
  static const dbFileName = 'spend_tracker.sqlite';
  static const legacyAndroidPackage = 'com.example.spend_tracker';
  static const currentAndroidPackage = 'com.arham.hisaab';
  static const onboardingCompleteKey = 'onboarding_complete';
  static const legacySeedCleanupKey = 'legacy_seed_cleanup_v1';

  /// Keys that indicate the user has configured the app before.
  static const _preferenceMarkers = [
    'show_income',
    'monthly_income',
    'track_inward_flow',
    'settings_tour_seen',
    'home_tour_seen',
    'account_holder_name',
    CategoryCatalog.storageKey,
  ];

  /// Detects returning users when SQLite or prefs survived but onboarding was reset.
  static Future<bool> hasExistingUserData({
    required TransactionRepository repository,
    required SharedPreferences prefs,
  }) async {
    if ((await repository.countTransactions()) > 0) return true;
    for (final key in _preferenceMarkers) {
      if (prefs.containsKey(key)) return true;
    }
    return false;
  }

  /// Skips first-run onboarding when history or settings are already on-device.
  static Future<bool> recoverReturningUser({
    required TransactionRepository repository,
    required SharedPreferences prefs,
  }) async {
    if (prefs.getBool(onboardingCompleteKey) ?? false) return false;

    final returning = await hasExistingUserData(
      repository: repository,
      prefs: prefs,
    );
    if (!returning) return false;

    await prefs.setBool(onboardingCompleteKey, true);
    return true;
  }

  /// Removes old demo rows once — never touches real captures (non-seed ids).
  static Future<void> cleanupLegacyDevDataOnce({
    required TransactionRepository repository,
    required SharedPreferences prefs,
  }) async {
    if (prefs.getBool(legacySeedCleanupKey) ?? false) return;
    await repository.deleteLegacySeedData();
    await prefs.setBool(legacySeedCleanupKey, true);
  }
}
