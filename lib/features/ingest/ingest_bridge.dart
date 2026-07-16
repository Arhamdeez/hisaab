import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../models/transaction.dart';

/// Result of attempting to open the OS notification-listener settings screen.
class NotificationAccessOpenResult {
  const NotificationAccessOpenResult({
    required this.opened,
    this.via,
    this.manufacturer = '',
    this.model = '',
    this.sdkInt = 0,
  });

  final bool opened;
  final String? via;
  final String manufacturer;
  final String model;
  final int sdkInt;

  factory NotificationAccessOpenResult.fromMap(Map<dynamic, dynamic> map) {
    return NotificationAccessOpenResult(
      opened: map['opened'] as bool? ?? false,
      via: map['via'] as String?,
      manufacturer: map['manufacturer'] as String? ?? '',
      model: map['model'] as String? ?? '',
      sdkInt: (map['sdkInt'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Outcome of copying data from the old dev package id on first launch.
class LegacyMigrationStatus {
  const LegacyMigrationStatus({
    required this.status,
    this.legacyInstalled = false,
    this.bytesCopied = 0,
    this.message,
  });

  final String status;
  final bool legacyInstalled;
  final int bytesCopied;
  final String? message;

  bool get migrated => status == 'migrated';
  bool get needsManualRestore =>
      status == 'legacy_locked' || status == 'failed';

  factory LegacyMigrationStatus.fromMap(Map<dynamic, dynamic> map) {
    return LegacyMigrationStatus(
      status: map['status'] as String? ?? 'unknown',
      legacyInstalled: map['legacyInstalled'] as bool? ?? false,
      bytesCopied: (map['bytesCopied'] as num?)?.toInt() ?? 0,
      message: map['message'] as String?,
    );
  }
}

class IngestEvent {
  const IngestEvent({
    required this.text,
    required this.source,
    required this.timestamp,
    this.packageName,
    this.notificationTitle,
  });

  final String text;
  final TransactionSource source;
  final DateTime timestamp;
  final String? packageName;

  /// [Notification.EXTRA_TITLE] — wallet apps often put the counterparty here.
  final String? notificationTitle;
}

class IngestBridge {
  IngestBridge._();

  static final IngestBridge instance = IngestBridge._();

  static const _eventChannel = EventChannel('com.arham.hisaab/ingest');
  static const _methodChannel =
      MethodChannel('com.arham.hisaab/ingest_control');

  final _controller = StreamController<IngestEvent>.broadcast();

  Stream<IngestEvent> get stream => _controller.stream;

  StreamSubscription<dynamic>? _subscription;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || !Platform.isAndroid) return;
    _initialized = true;

    _subscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is! Map) return;
        final map = Map<String, dynamic>.from(event);
        final sourceKey = map['source'] as String? ?? 'notification';
        final source = TransactionSourceX.fromKey(sourceKey);
        final rawTs = map['timestamp'] as int?;
        final timestampMs = (rawTs == null || rawTs <= 0)
            ? DateTime.now().millisecondsSinceEpoch
            : rawTs;

        _controller.add(
          IngestEvent(
            text: map['text'] as String? ?? '',
            source: source,
            timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
            packageName: map['package'] as String?,
            notificationTitle: _readTitle(map),
          ),
        );
      },
      onError: (Object e) {
        debugPrint('IngestBridge error: $e');
      },
    );
  }

  /// Pulls any events the native side buffered while Flutter wasn't listening
  /// (app closed / backgrounded) from durable SQLite + legacy prefs. Safe to
  /// call repeatedly; native buffers are cleared on read.
  Future<List<IngestEvent>> drainPending() async {
    if (!Platform.isAndroid) return const [];
    try {
      final raw = await _methodChannel.invokeMethod<List<dynamic>>(
        'drainPending',
      );
      if (raw == null) return const [];
      return raw.whereType<Map>().map((item) {
        final map = Map<String, dynamic>.from(item);
        final sourceKey = map['source'] as String? ?? 'notification';
        final rawTs = (map['timestamp'] as num?)?.toInt();
        final timestampMs = (rawTs == null || rawTs <= 0)
            ? DateTime.now().millisecondsSinceEpoch
            : rawTs;
        final package = map['package'] as String?;
        return IngestEvent(
          text: map['text'] as String? ?? '',
          source: TransactionSourceX.fromKey(sourceKey),
          timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
          packageName: (package != null && package.isEmpty) ? null : package,
          notificationTitle: _readTitle(map),
        );
      }).toList();
    } catch (e) {
      debugPrint('IngestBridge drainPending error: $e');
      return const [];
    }
  }

  static String? _readTitle(Map<String, dynamic> map) {
    final sourceKey = map['source'] as String? ?? 'notification';
    final title = (map['sender'] as String?) ?? (map['title'] as String?);
    if (title == null || title.trim().isEmpty) return null;
    final trimmed = title.trim();
    // Easypaisa 3737, Raast 8558, etc. — the merchant is in the SMS body.
    if (sourceKey == 'sms' && RegExp(r'^\d{3,6}$').hasMatch(trimmed)) {
      return null;
    }
    return trimmed;
  }

  Future<bool> isNotificationAccessEnabled() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'isNotificationAccessEnabled',
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<NotificationAccessOpenResult> openNotificationAccessSettings() async {
    if (!Platform.isAndroid) {
      return const NotificationAccessOpenResult(opened: false);
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'openNotificationAccessSettings',
      );
      if (result == null) {
        return const NotificationAccessOpenResult(opened: false);
      }
      return NotificationAccessOpenResult.fromMap(result);
    } catch (e) {
      debugPrint('IngestBridge openNotificationAccessSettings error: $e');
      return const NotificationAccessOpenResult(opened: false);
    }
  }

  Future<LegacyMigrationStatus> getLegacyMigrationStatus() async {
    if (!Platform.isAndroid) {
      return const LegacyMigrationStatus(status: 'unsupported');
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getLegacyMigrationStatus',
      );
      if (result == null) {
        return const LegacyMigrationStatus(status: 'unknown');
      }
      return LegacyMigrationStatus.fromMap(result);
    } catch (e) {
      debugPrint('IngestBridge getLegacyMigrationStatus error: $e');
      return LegacyMigrationStatus(status: 'error', message: e.toString());
    }
  }

  Future<void> startKeepAlive() async {
    if (!Platform.isAndroid) return;
    try {
      await _methodChannel.invokeMethod<void>('startKeepAlive');
    } catch (e) {
      debugPrint('IngestBridge startKeepAlive error: $e');
    }
  }

  Future<void> stopKeepAlive() async {
    if (!Platform.isAndroid) return;
    try {
      await _methodChannel.invokeMethod<void>('stopKeepAlive');
    } catch (e) {
      debugPrint('IngestBridge stopKeepAlive error: $e');
    }
  }

  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'isIgnoringBatteryOptimizations',
      );
      return result ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _methodChannel.invokeMethod<void>(
        'openBatteryOptimizationSettings',
      );
    } catch (e) {
      debugPrint('IngestBridge battery settings error: $e');
    }
  }

  Future<bool> hasPendingCaptures() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'hasPendingCaptures',
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Samsung and some OEMs disconnect the listener silently — nudge a rebind.
  Future<void> requestNotificationRebind() async {
    if (!Platform.isAndroid) return;
    try {
      await _methodChannel.invokeMethod<void>('requestNotificationRebind');
    } catch (e) {
      debugPrint('IngestBridge rebind error: $e');
    }
  }

  /// Re-reads alerts still sitting in the notification shade (EasyPaisa, Gmail, …).
  /// [force] — bypass throttle (cold start, pull-to-refresh).
  Future<void> scanActiveNotifications({bool force = false}) async {
    if (!Platform.isAndroid) return;
    try {
      await _methodChannel.invokeMethod<void>(
        'scanActiveNotifications',
        {'force': force},
      );
    } catch (e) {
      debugPrint('IngestBridge scan error: $e');
    }
  }

  /// Re-reads recent wallet/bank SMS from the inbox (Easypaisa 3737, Raast 8558, …).
  ///
  /// [walletShortCodesOnly] — when true, only known wallet senders (fast path for
  /// app open / resume). Pull-to-refresh uses the full 2-day scan.
  Future<void> scanRecentSms({bool walletShortCodesOnly = false}) async {
    if (!Platform.isAndroid) return;
    try {
      await _methodChannel.invokeMethod<void>(
        'scanRecentSms',
        {'walletShortCodesOnly': walletShortCodesOnly},
      );
    } catch (e) {
      debugPrint('IngestBridge scanRecentSms error: $e');
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
  }
}
