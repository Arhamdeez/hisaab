import 'dart:convert';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;

import '../../core/database/app_database.dart';
import '../../core/config/gmail_config.dart';

class GmailMessage {
  const GmailMessage({required this.body, required this.receivedAt});

  final String body;
  final DateTime receivedAt;
}

class GmailService {
  GmailService();

  static const _historyKey = 'gmail_history_id';
  static const _scope = gmail.GmailApi.gmailReadonlyScope;

  final _storage = const FlutterSecureStorage();
  final _googleSignIn = GoogleSignIn(
    scopes: [_scope],
    serverClientId: GmailConfig.serverClientId,
  );

  GoogleSignInAccount? _account;
  AppDatabase? _db;

  bool get isConnected => _account != null;

  Future<void> initialize(AppDatabase db) async {
    _db = db;
    try {
      _account = await _googleSignIn.signInSilently();
    } catch (e) {
      debugPrint('Gmail silent sign-in failed: $e');
    }
  }

  Future<bool> signIn() async {
    try {
      _account = await _googleSignIn.signIn();
      return _account != null;
    } catch (e) {
      debugPrint('Gmail sign-in failed: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _account = null;
    if (_db != null) await _db!.setSyncValue(_historyKey, '');
  }

  Future<List<GmailMessage>> fetchTransactionEmails() async {
    if (_account == null || _db == null) return [];

    try {
      final client = await _googleSignIn.authenticatedClient();
      if (client == null) return [];

      final api = gmail.GmailApi(client);
      final query = GmailConfig.searchQuery;

      final list = await api.users.messages.list(
        'me',
        q: query,
        maxResults: 50,
      );

      final messages = <GmailMessage>[];
      final ids = list.messages ?? [];

      for (final ref in ids) {
        if (ref.id == null) continue;
        final full = await api.users.messages.get('me', ref.id!);
        final body = _extractBody(full);
        if (body.isEmpty) continue;

        final receivedAt = full.internalDate != null
            ? DateTime.fromMillisecondsSinceEpoch(
                int.parse(full.internalDate!),
              )
            : DateTime.now();

        messages.add(GmailMessage(body: body, receivedAt: receivedAt));
      }

      if (messages.isNotEmpty) {
        final profile = await api.users.getProfile('me');
        if (profile.historyId != null) {
          await _db!.setSyncValue(_historyKey, profile.historyId!);
          await _storage.write(key: _historyKey, value: profile.historyId);
        }
      }

      return messages;
    } catch (e) {
      debugPrint('Gmail fetch failed: $e');
      return [];
    }
  }

  String _extractBody(gmail.Message message) {
    final parts = <String>[];

    void walk(gmail.MessagePart? part) {
      if (part == null) return;
      final data = part.body?.data;
      if (data != null && data.isNotEmpty) {
        try {
          final normalized = base64Url.normalize(data);
          parts.add(utf8.decode(base64Url.decode(normalized)));
        } catch (_) {}
      }
      for (final child in part.parts ?? <gmail.MessagePart>[]) {
        walk(child);
      }
    }

    walk(message.payload);
    if (parts.isEmpty && message.snippet != null) {
      return message.snippet!;
    }
    return parts.join('\n');
  }
}
