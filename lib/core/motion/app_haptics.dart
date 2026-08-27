import 'package:flutter/services.dart';

import '../../providers/app_preferences.dart';

/// All in-app vibration goes through here so Settings can silence it.
abstract final class AppHaptics {
  static bool get enabled => AppPreferences.instance.hapticsEnabled;

  static Future<void> selectionClick() async {
    if (!enabled) return;
    await HapticFeedback.selectionClick();
  }

  static Future<void> lightImpact() async {
    if (!enabled) return;
    await HapticFeedback.lightImpact();
  }

  static Future<void> mediumImpact() async {
    if (!enabled) return;
    await HapticFeedback.mediumImpact();
  }

  static Future<void> heavyImpact() async {
    if (!enabled) return;
    await HapticFeedback.heavyImpact();
  }
}
