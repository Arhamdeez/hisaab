import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the most recent uncaught error on-device so the user can attach it
/// when they choose to report — nothing is sent automatically.
abstract final class CrashBuffer {
  static const _key = 'last_crash_report_v1';

  static Future<void> record(Object error, StackTrace stack) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'at': DateTime.now().toIso8601String(),
      'error': error.toString(),
      'stack': _trimStack(stack),
    };
    await prefs.setString(_key, jsonEncode(payload));
  }

  static Future<CrashSnapshot?> latest() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return CrashSnapshot(
        at: DateTime.tryParse(map['at'] as String? ?? '') ?? DateTime.now(),
        error: map['error'] as String? ?? 'Unknown error',
        stack: map['stack'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static String _trimStack(StackTrace stack) {
    final lines = stack.toString().split('\n');
    if (lines.length <= 24) return stack.toString();
    return '${lines.take(24).join('\n')}\n… (${lines.length - 24} more frames)';
  }
}

class CrashSnapshot {
  const CrashSnapshot({
    required this.at,
    required this.error,
    required this.stack,
  });

  final DateTime at;
  final String error;
  final String stack;

  String format() {
    return 'Time: $at\nError: $error\n\n$stack';
  }
}
