import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/database/app_database.dart';
import '../../core/repositories/transaction_repository.dart';
import '../../models/transaction.dart';
import '../../providers/app_preferences.dart';
import '../dedup/deduplicator.dart';
import '../dedup/review_policy.dart';
import '../notifications/notification_service.dart';
import '../parser/transaction_parser.dart';
import 'gmail_service.dart';
import 'ingest_bridge.dart';

class IngestService extends ChangeNotifier with WidgetsBindingObserver {
  IngestService({
    required TransactionRepository repository,
    required AppDatabase database,
    required GmailService gmailService,
  })  : _repository = repository,
        _deduplicator = Deduplicator(repository),
        _parser = TransactionParser(),
        _gmail = gmailService,
        _database = database;

  final TransactionRepository _repository;
  final Deduplicator _deduplicator;
  final TransactionParser _parser;
  final GmailService _gmail;
  final AppDatabase _database;

  bool _listening = false;
  bool _notificationAccess = false;
  bool _batteryUnrestricted = true;
  Timer? _foregroundSafetyTimer;

  bool get isListening => _listening;
  bool get isGmailConnected => _gmail.isConnected;
  bool get isBatteryUnrestricted => _batteryUnrestricted;

  /// Whether the OS has actually granted notification-listener access. This is
  /// the real capture state (the bridge being initialized is not enough).
  bool get hasNotificationAccessGranted => _notificationAccess;

  StreamSubscription<IngestEvent>? _ingestSubscription;

  Future<void> initialize() async {
    // Attach before native EventChannel so live alerts are not dropped.
    _ingestSubscription =
        IngestBridge.instance.stream.listen(_handleIngestEvent);

    await NotificationService.instance.initialize();
    NotificationService.instance.onForegroundDecision = _applyDecision;
    await IngestBridge.instance.initialize();
    await _gmail.initialize(_database);

    _listening = true;

    WidgetsBinding.instance.addObserver(this);
    _startForegroundSafetyTimer();

    // Pull in anything captured while the app was closed, then verify access.
    await _scanAndDrain();
    await _drainNotificationActionsIfQueued();
    await refreshNotificationAccess();
    await refreshBatteryOptimization();
    await _syncCapturePipeline();
    notifyListeners();
  }

  /// Scans the notification shade and drains the native capture queue.
  Future<void> syncCaptures() => _scanAndDrain();

  Future<void> _scanAndDrain() async {
    await IngestBridge.instance.scanActiveNotifications();
    if (Platform.isAndroid) {
      final sms = await Permission.sms.status;
      if (sms.isGranted || sms.isLimited) {
        await IngestBridge.instance.scanRecentSms();
      }
    }
    await _drainPendingIfNeeded();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_onResumed());
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        unawaited(_onBackground());
      case AppLifecycleState.detached:
        _foregroundSafetyTimer?.cancel();
      case AppLifecycleState.inactive:
        break;
    }
  }

  Future<void> _onResumed() async {
    await refreshNotificationAccess();
    await refreshBatteryOptimization();
    await IngestBridge.instance.requestNotificationRebind();
    await _scanAndDrain();
    await _drainNotificationActionsIfQueued();
    notifyListeners();
  }

  Future<void> _onBackground() async {
    if (_notificationAccess) {
      await IngestBridge.instance.startKeepAlive();
    }
  }

  /// Applies a single quick-reply decision on the main isolate (fast path).
  Future<void> _applyDecision(NotificationDecision decision) async {
    final changed = await NotificationService.instance.applyDecision(
      _repository,
      decision,
      fast: true,
    );
    if (changed) notifyListeners();
  }

  /// Rare safety net while the app is open — skips work when the queue is empty.
  void _startForegroundSafetyTimer() {
    _foregroundSafetyTimer?.cancel();
    _foregroundSafetyTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      unawaited(_scanAndDrain());
    });
  }

  Future<void> _syncCapturePipeline() async {
    if (!await IngestBridge.instance.isNotificationAccessEnabled()) {
      await IngestBridge.instance.stopKeepAlive();
      return;
    }
    await IngestBridge.instance.requestNotificationRebind();

    // Samsung/OEM builds drop the listener without a foreground service — keep it
    // running whenever notification access is granted.
    if (_notificationAccess) {
      await IngestBridge.instance.startKeepAlive();
    } else {
      await IngestBridge.instance.stopKeepAlive();
    }
  }

  Future<bool> refreshBatteryOptimization() async {
    final unrestricted =
        await IngestBridge.instance.isIgnoringBatteryOptimizations();
    if (unrestricted != _batteryUnrestricted) {
      _batteryUnrestricted = unrestricted;
      notifyListeners();
    }
    return unrestricted;
  }

  Future<void> requestBatteryOptimizationExemption() =>
      IngestBridge.instance.requestIgnoreBatteryOptimizations();

  Future<void> _drainNotificationActionsIfQueued() async {
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    if (!await NotificationService.hasPendingActions()) return;
    await _drainNotificationActions();
  }

  /// Applies decisions queued from background notification actions.
  Future<void> _drainNotificationActions() async {
    final changed =
        await NotificationService.instance.drainPendingActions(_repository);
    if (changed) notifyListeners();
  }

  Future<void> _drainPendingIfNeeded() async {
    await _drainPending();
  }

  Future<void> _drainPending() async {
    final pending = await IngestBridge.instance.drainPending();
    final seen = <String>{};
    for (final event in pending) {
      if (event.text.trim().isEmpty) continue;
      final key =
          '${event.source.storageKey}|${event.timestamp.millisecondsSinceEpoch}|${event.text.hashCode}';
      if (!seen.add(key)) continue;
      await _handleIngestEvent(event);
    }
  }

  /// Re-reads the OS notification-access state and notifies listeners on change.
  Future<bool> refreshNotificationAccess() async {
    final enabled = await IngestBridge.instance.isNotificationAccessEnabled();
    if (enabled != _notificationAccess) {
      _notificationAccess = enabled;
      notifyListeners();
    }
    if (enabled) {
      await _syncCapturePipeline();
    } else {
      await IngestBridge.instance.stopKeepAlive();
    }
    return enabled;
  }

  Future<void> _handleIngestEvent(IngestEvent event) async {
    if (event.text.trim().isEmpty) return;

    final parsed = _parser.parse(
      event.text,
      source: event.source,
      fallbackTime: event.timestamp,
      packageName: event.packageName,
      notificationTitle: event.notificationTitle,
    );
    if (parsed == null) {
      debugPrint(
        'IngestService: could not parse capture from ${event.packageName ?? event.source.storageKey}: '
        '"${event.text.replaceAll('\n', ' ').trim()}"',
      );
      return;
    }

    final outcome = await _deduplicator.processIncoming(
      parsed: parsed,
      source: event.source,
      rawText: event.text,
      messageTime: event.timestamp,
      accountHolderName: await _accountHolderNameForReview(event.text),
    );

    // Short confirmation whenever a new payment is tracked.
    final captured = outcome.transaction;
    if (outcome.result == DedupResult.created && captured != null) {
      final alertAge = DateTime.now().difference(event.timestamp);
      if (alertAge <= const Duration(hours: 48)) {
        await NotificationService.instance.showTransactionCaptured(captured);
      }
    }

    notifyListeners();
  }

  Future<int> syncGmail() async {
    final messages = await _gmail.fetchTransactionEmails();
    var count = 0;
    final processedIds = <String>[];
    for (final msg in messages) {
      final parsed = _parser.parse(
        msg.body,
        source: TransactionSource.gmail,
        fallbackTime: msg.receivedAt,
      );
      processedIds.add(msg.id);
      if (parsed == null) continue;

      final outcome = await _deduplicator.processIncoming(
        parsed: parsed,
        source: TransactionSource.gmail,
        rawText: msg.body,
        messageTime: msg.receivedAt,
        accountHolderName: await _accountHolderNameForReview(msg.body),
      );
      if (outcome.result == DedupResult.created) {
        count++;
        final captured = outcome.transaction;
        if (captured != null) {
          await NotificationService.instance.showTransactionCaptured(captured);
        }
      }
    }
    if (processedIds.isNotEmpty) {
      await _gmail.markProcessed(processedIds);
    }
    notifyListeners();
    return count;
  }

  Future<bool> connectGmail() async {
    final ok = await _gmail.signIn();
    if (ok) notifyListeners();
    return ok;
  }

  Future<void> disconnectGmail() async {
    await _gmail.signOut();
    notifyListeners();
  }

  Future<void> openNotificationSettings() =>
      IngestBridge.instance.openNotificationAccessSettings();

  Future<bool> hasNotificationAccess() =>
      IngestBridge.instance.isNotificationAccessEnabled();

  Future<String> _accountHolderNameForReview(String rawText) async {
    await AppPreferences.instance.learnAccountHolderName(
      ReviewPolicy.extractAccountHolderName(rawText),
    );
    return AppPreferences.instance.accountHolderName;
  }

  @override
  void dispose() {
    _foregroundSafetyTimer?.cancel();
    _ingestSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
