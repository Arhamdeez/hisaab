import 'dart:io';

import 'package:flutter/services.dart';

/// iOS: include the spending database in the phone's backup.
abstract final class IcloudBackup {
  static const _channel = MethodChannel('com.arham.hisaab/local_store');

  static Future<void> includeSqliteInBackup() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('includeSqliteInBackup');
    } catch (_) {
      // Channel missing in tests / older builds — local data still works.
    }
  }
}
