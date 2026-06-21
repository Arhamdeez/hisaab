import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../models/transaction.dart';

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

  static const _eventChannel = EventChannel('com.example.spend_tracker/ingest');
  static const _methodChannel =
      MethodChannel('com.example.spend_tracker/ingest_control');

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
        final timestampMs = map['timestamp'] as int? ??
            DateTime.now().millisecondsSinceEpoch;

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
        final timestampMs = (map['timestamp'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch;
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
    final title = (map['sender'] as String?) ?? (map['title'] as String?);
    if (title == null || title.trim().isEmpty) return null;
    return title.trim();
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

  Future<void> openNotificationAccessSettings() async {
    if (!Platform.isAndroid) return;
    await _methodChannel.invokeMethod<void>('openNotificationAccessSettings');
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

  Future<void> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return;
    try {
      await _methodChannel.invokeMethod<void>(
        'requestIgnoreBatteryOptimizations',
      );
    } catch (e) {
      debugPrint('IngestBridge battery opt error: $e');
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
  Future<void> scanActiveNotifications() async {
    if (!Platform.isAndroid) return;
    try {
      await _methodChannel.invokeMethod<void>('scanActiveNotifications');
    } catch (e) {
      debugPrint('IngestBridge scan error: $e');
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
  }
}
