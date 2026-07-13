import 'package:flutter/foundation.dart';

/// Debug-only logging that never prints full payment alert bodies in release.
abstract final class SafeLog {
  static void d(String message) {
    if (kDebugMode) debugPrint(message);
  }

  static void ingest(String message) {
    if (kDebugMode) debugPrint('[ingest] $message');
  }

  /// Redacts alert/SMS bodies for developer logs — never log full content in prod.
  static String redact(String text, {int head = 0}) {
    final trimmed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (trimmed.isEmpty) return '(empty)';
    if (head <= 0) return '(${trimmed.length} chars)';
    if (trimmed.length <= head) return '(${trimmed.length} chars)';
    return '${trimmed.substring(0, head)}… (${trimmed.length} chars)';
  }
}
