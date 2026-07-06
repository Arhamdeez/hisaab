import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/repositories/transaction_repository.dart';
import '../../models/transaction.dart';
import '../../providers/app_preferences.dart';
import '../dedup/deduplicator.dart';
import '../dedup/review_policy.dart';
import '../notifications/notification_service.dart';
import '../parser/transaction_parser.dart';
import 'ingest_bridge.dart';

/// Parses captured alerts and writes them to the local database — shared by
/// the foreground app and the Android background ingest worker.
class IngestProcessor {
  IngestProcessor({required TransactionRepository repository})
      : _deduplicator = Deduplicator(repository),
        _parser = TransactionParser();

  final Deduplicator _deduplicator;
  final TransactionParser _parser;
  final _processing = <String, Future<bool>>{};

  /// Processes one live capture (EventChannel) that never touched the native queue.
  Future<bool> processLiveEvent(IngestEvent event) async {
    if (event.text.trim().isEmpty) return false;
    return _processEvent(event);
  }

  /// Rescans OS sources, drains the native queue, and returns rows created or merged.
  Future<int> processPendingQueue({bool rescanSources = false}) async {
    if (rescanSources && Platform.isAndroid) {
      await IngestBridge.instance.scanActiveNotifications(force: true);
      final sms = await Permission.sms.status;
      if (sms.isGranted || sms.isLimited) {
        await IngestBridge.instance.scanRecentSms(walletShortCodesOnly: false);
      }
    }

    final pending = await IngestBridge.instance.drainPending();
    final seen = <String>{};
    var changed = 0;

    for (final event in pending) {
      if (event.text.trim().isEmpty) continue;
      final source = _resolveSource(event);
      final key = _stableEventKey(event, source);
      if (!seen.add(key)) continue;
      if (await _processEvent(event)) changed++;
    }

    return changed;
  }

  Future<bool> _processEvent(IngestEvent event) async {
    final source = _resolveSource(event);
    final key = _stableEventKey(event, source);

    return _processing.putIfAbsent(key, () async {
      try {
        final parsed = _parser.parse(
          event.text,
          source: source,
          fallbackTime: event.timestamp,
          packageName: event.packageName,
          notificationTitle: event.notificationTitle,
        );
        if (parsed == null) {
          debugPrint(
            'IngestProcessor: could not parse ${event.packageName ?? event.source.storageKey}: '
            '"${event.text.replaceAll('\n', ' ').trim()}"',
          );
          return false;
        }

        final outcome = await _deduplicator.processIncoming(
          parsed: parsed,
          source: source,
          rawText: event.text,
          messageTime: event.timestamp,
          accountHolderName: await _accountHolderNameForReview(event.text),
        );

        final captured = outcome.transaction;
        if (outcome.result == DedupResult.created && captured != null) {
          debugPrint(
            'IngestProcessor: saved ${captured.amount} ${captured.type.name} '
            '→ ${captured.merchant} (${captured.source.storageKey})',
          );
          final alertAge = DateTime.now().difference(event.timestamp);
          if (alertAge <= const Duration(hours: 48)) {
            await NotificationService.instance.showTransactionCaptured(captured);
          }
          return true;
        }
        if (outcome.result == DedupResult.merged) {
          debugPrint(
            'IngestProcessor: merged duplicate ${parsed.amount} '
            '${parsed.type.name} → ${parsed.merchant}',
          );
        }
        return outcome.result == DedupResult.merged;
      } finally {
        _processing.remove(key);
      }
    });
  }

  Future<String> _accountHolderNameForReview(String rawText) async {
    await AppPreferences.instance.learnAccountHolderName(
      ReviewPolicy.extractAccountHolderName(rawText),
    );
    return AppPreferences.instance.accountHolderName;
  }

  /// Gmail app notifications are treated as email for cross-source dedup.
  static TransactionSource _resolveSource(IngestEvent event) {
    final pkg = event.packageName;
    if (pkg != null && pkg.startsWith('com.google.android.gm')) {
      return TransactionSource.gmail;
    }
    return event.source;
  }

  /// Collapses truncated vs full Gmail/NayaPay duplicates for the same payment.
  static String _stableEventKey(IngestEvent event, TransactionSource source) {
    final flat = event.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final amountMatch = RegExp(
      r'(?:rs\.?|pkr)\.?\s*([\d,]+(?:\.\d+)?)',
      caseSensitive: false,
    ).firstMatch(flat);
    final pkg = event.packageName;
    if (amountMatch != null && pkg != null) {
      final amount = amountMatch.group(1)!.replaceAll(',', '');
      final minute = event.timestamp.millisecondsSinceEpoch ~/ 60000;
      return '${source.storageKey}|$pkg|$amount|$minute';
    }
    return '${source.storageKey}|${event.timestamp.millisecondsSinceEpoch}|${flat.hashCode}';
  }
}
