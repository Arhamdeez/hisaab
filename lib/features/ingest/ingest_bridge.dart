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
    this.sender,
  });

  final String text;
  final TransactionSource source;
  final DateTime timestamp;
  final String? packageName;
  final String? sender;
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
            sender: map['sender'] as String?,
          ),
        );
      },
      onError: (Object e) {
        debugPrint('IngestBridge error: $e');
      },
    );
  }

  /// Pulls any events the native side buffered while Flutter wasn't listening
  /// (app closed / backgrounded) so background-captured transactions are not
  /// lost. Safe to call repeatedly; the native buffer is cleared on read.
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
        final sender = map['sender'] as String?;
        return IngestEvent(
          text: map['text'] as String? ?? '',
          source: TransactionSourceX.fromKey(sourceKey),
          timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
          packageName: (package != null && package.isEmpty) ? null : package,
          sender: (sender != null && sender.isEmpty) ? null : sender,
        );
      }).toList();
    } catch (e) {
      debugPrint('IngestBridge drainPending error: $e');
      return const [];
    }
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

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
  }
}
