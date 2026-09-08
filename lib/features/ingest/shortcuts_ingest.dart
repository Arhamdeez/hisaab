import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../models/transaction.dart';
import 'ingest_bridge.dart';

/// Back Tap / `hisaab://capture` payload for the island prompt.
class CapturePrompt {
  const CapturePrompt({this.clipboardText});

  final String? clipboardText;
}

/// iOS Shortcuts → HISAAB ingest.
///
/// Native App Intent / SceneDelegate send the SMS over a method channel.
/// `hisaab://import?text=…` still works as a fallback.
/// Back Tap opens [capturePrompt] instead of auto-logging.
///
/// Android is untouched — this class no-ops unless [Platform.isIOS].
class ShortcutsIngest {
  ShortcutsIngest._();

  static final ShortcutsIngest instance = ShortcutsIngest._();

  static const urlScheme = 'hisaab';
  static const importHost = 'import';
  static const captureHost = 'capture';
  static const _channelName = 'com.arham.hisaab/shortcuts';

  /// Example URL users put in Shortcuts (text is appended by the automation).
  static const importUrlPrefix = '$urlScheme://$importHost?text=';

  final _appLinks = AppLinks();
  final _channel = const MethodChannel(_channelName);
  StreamSubscription<Uri>? _subscription;
  Future<void> Function(IngestEvent event)? _onEvent;
  bool _started = false;
  String? _lastText;
  DateTime? _lastAt;

  /// Island prompt (Back Tap). Null when hidden.
  final ValueNotifier<CapturePrompt?> capturePrompt = ValueNotifier(null);

  /// Parses a Shortcuts / deep-link URI into an [IngestEvent], or null if invalid.
  static IngestEvent? eventFromUri(Uri uri) {
    if (uri.scheme.toLowerCase() != urlScheme) return null;
    if (isCaptureUri(uri)) return null;

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

  static bool isCaptureUri(Uri uri) {
    if (uri.scheme.toLowerCase() != urlScheme) return false;
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    return host == captureHost || path == '/$captureHost' || path == captureHost;
  }

  /// Accepts a `hisaab://` URL **or** a plain SMS body (from the App Intent).
  static IngestEvent? eventFromRaw(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.toLowerCase().startsWith('$urlScheme:')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null) {
        if (isCaptureUri(uri)) return null;
        final event = eventFromUri(uri);
        if (event != null) return event;
      }
      final match = RegExp(r'[?&](?:text|body)=(.+)$', caseSensitive: false)
          .firstMatch(trimmed);
      if (match != null) {
        var value = match.group(1) ?? '';
        final amp = value.indexOf('&');
        if (amp >= 0) value = value.substring(0, amp);
        value = Uri.decodeQueryComponent(value.replaceAll('+', ' ')).trim();
        if (value.isNotEmpty) {
          return IngestEvent(
            text: value,
            source: TransactionSource.sms,
            timestamp: DateTime.now(),
          );
        }
      }
      return null;
    }

    return IngestEvent(
      text: trimmed,
      source: TransactionSource.sms,
      timestamp: DateTime.now(),
    );
  }

  /// Starts listening for cold-start and warm deep links (iOS only).
  Future<void> start(Future<void> Function(IngestEvent event) onEvent) async {
    if (_started || !Platform.isIOS) return;
    _started = true;
    _onEvent = onEvent;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'importText') {
        await _emitRaw(call.arguments);
        await drainPending();
      } else if (call.method == 'showCapture') {
        await presentCapturePrompt(clipboard: call.arguments?.toString());
      }
    });

    await drainPending();
    // App Intent may finish after Flutter starts — keep checking briefly.
    unawaited(_pollPending());

    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        await _handleUri(initial);
      }
    } catch (e) {
      debugPrint('ShortcutsIngest initial link error: $e');
    }

    _subscription = _appLinks.uriLinkStream.listen(
      (uri) async {
        await _handleUri(uri);
      },
      onError: (Object e) {
        debugPrint('ShortcutsIngest stream error: $e');
      },
    );
  }

  Future<void> _handleUri(Uri uri) async {
    if (isCaptureUri(uri)) {
      final text = (uri.queryParameters['text'] ??
              uri.queryParameters['body'] ??
              '')
          .trim();
      // Native island only — do not cover the Flutter app with a sheet.
      // A URL still activates the process; Back Tap must use the App Intent.
      final started = await startIsland(clipboard: text.isEmpty ? null : text);
      if (!started) {
        await presentCapturePrompt(clipboard: text);
      }
      return;
    }
    await _emitEvent(eventFromUri(uri));
  }

  /// Starts the real Dynamic Island Live Activity (does not push a Flutter route).
  Future<bool> startIsland({String? clipboard}) async {
    if (!Platform.isIOS) return false;
    try {
      final ok = await _channel.invokeMethod<bool>(
        'startIsland',
        clipboard,
      );
      return ok == true;
    } catch (e) {
      debugPrint('ShortcutsIngest startIsland error: $e');
      return false;
    }
  }

  /// Shows the Dynamic Island–style “what to add” prompt.
  Future<void> presentCapturePrompt({String? clipboard}) async {
    var text = clipboard?.trim() ?? '';
    if (text.isEmpty) {
      try {
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        text = data?.text?.trim() ?? '';
      } catch (_) {}
    }
    capturePrompt.value = CapturePrompt(
      clipboardText: text.isEmpty ? null : text,
    );
  }

  void dismissCapture() {
    capturePrompt.value = null;
  }

  /// Pulls text stashed natively (cold start, or missed live `importText`).
  Future<void> drainPending() async {
    if (!Platform.isIOS) return;
    try {
      final pending = await _channel.invokeMethod<dynamic>('takePending');
      await _handlePending(pending);
    } catch (e) {
      debugPrint('ShortcutsIngest pending error: $e');
    }
  }

  Future<void> _handlePending(Object? pending) async {
    if (pending == null) return;
    if (pending is Map) {
      final mode = pending['mode']?.toString();
      final text = pending['text']?.toString() ?? '';
      if (mode == 'prompt') {
        await presentCapturePrompt(clipboard: text);
        return;
      }
      await _emitRaw(text);
      return;
    }
    await _emitRaw(pending);
  }

  Future<void> _pollPending() async {
    for (var i = 0; i < 8; i++) {
      if (!_started) return;
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!_started) return;
      await drainPending();
    }
  }

  Future<void> _emitRaw(Object? raw) async {
    final value = raw?.toString() ?? '';
    await _emitEvent(eventFromRaw(value));
  }

  Future<void> _emitEvent(IngestEvent? event) async {
    if (event == null) return;
    final text = event.text.trim();
    if (text.isEmpty) return;
    final now = DateTime.now();
    if (_lastText == text &&
        _lastAt != null &&
        now.difference(_lastAt!) < const Duration(seconds: 4)) {
      return;
    }
    _lastText = text;
    _lastAt = now;
    final onEvent = _onEvent;
    if (onEvent == null) return;
    try {
      await onEvent(event);
    } catch (e) {
      debugPrint('ShortcutsIngest handle error: $e');
    }
  }

  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
    await _subscription?.cancel();
    _subscription = null;
    _onEvent = null;
    _started = false;
    capturePrompt.value = null;
  }
}
