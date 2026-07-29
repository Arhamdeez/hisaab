import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import '../../models/transaction.dart';
import 'ingest_bridge.dart';

/// iOS Shortcuts → HISAAB deep-link ingest.
///
/// Shortcut opens:
///   `hisaab://import?text=ENCODED_SMS_BODY&title=OPTIONAL_SENDER`
///
/// Android is untouched — this class no-ops unless [Platform.isIOS].
class ShortcutsIngest {
  ShortcutsIngest._();

  static final ShortcutsIngest instance = ShortcutsIngest._();

  static const urlScheme = 'hisaab';
  static const importHost = 'import';

  /// Example URL users put in Shortcuts (text is appended by the automation).
  static const importUrlPrefix = '$urlScheme://$importHost?text=';

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  bool _started = false;

  /// Parses a Shortcuts / deep-link URI into an [IngestEvent], or null if invalid.
  static IngestEvent? eventFromUri(Uri uri) {
    if (uri.scheme.toLowerCase() != urlScheme) return null;

    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    final isImport = host == importHost ||
        path == '/$importHost' ||
        path == importHost ||
        (host.isEmpty && (path.isEmpty || path == '/'));
    if (!isImport && host.isNotEmpty && host != importHost) return null;

    final params = uri.queryParameters;
    final text = (params['text'] ?? params['body'] ?? '').trim();
    if (text.isEmpty) return null;

    final title = (params['title'] ?? params['sender'] ?? '').trim();
    final sourceKey = (params['source'] ?? 'sms').trim().toLowerCase();
    final source = switch (sourceKey) {
      'notification' => TransactionSource.notification,
      'gmail' => TransactionSource.gmail,
      'manual' => TransactionSource.manual,
      _ => TransactionSource.sms,
    };

    final rawTs = int.tryParse(params['ts'] ?? '');
    final timestamp = rawTs != null && rawTs > 0
        ? DateTime.fromMillisecondsSinceEpoch(rawTs)
        : DateTime.now();

    return IngestEvent(
      text: text,
      source: source,
      timestamp: timestamp,
      notificationTitle: title.isEmpty ? null : title,
    );
  }

  /// Starts listening for cold-start and warm deep links (iOS only).
  Future<void> start(Future<void> Function(IngestEvent event) onEvent) async {
    if (_started || !Platform.isIOS) return;
    _started = true;

    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        final event = eventFromUri(initial);
        if (event != null) await onEvent(event);
      }
    } catch (e) {
      debugPrint('ShortcutsIngest initial link error: $e');
    }

    _subscription = _appLinks.uriLinkStream.listen(
      (uri) async {
        final event = eventFromUri(uri);
        if (event == null) return;
        try {
          await onEvent(event);
        } catch (e) {
          debugPrint('ShortcutsIngest handle error: $e');
        }
      },
      onError: (Object e) {
        debugPrint('ShortcutsIngest stream error: $e');
      },
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
  }
}
