import 'dart:io';

import 'package:flutter/services.dart';

/// iOS: keep spending SQLite out of iCloud (Android already disables backup).
abstract final class IcloudBackup {
  static const _channel = MethodChannel('com.arham.hisaab/local_store');

  static Future<void> excludeSqlite() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('excludeSqliteFromBackup');
    } catch (_) {
      // Channel missing in tests / older builds — local data still works.
    }
  }
}
