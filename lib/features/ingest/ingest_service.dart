import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/database/app_database.dart';
import '../../core/repositories/transaction_repository.dart';
import '../../models/transaction.dart';
import '../dedup/deduplicator.dart';
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
  Timer? _notificationDrainTimer;

  bool get isListening => _listening;
  bool get isGmailConnected => _gmail.isConnected;

  /// Whether the OS has actually granted notification-listener access. This is
  /// the real capture state (the bridge being initialized is not enough).
  bool get hasNotificationAccessGranted => _notificationAccess;

  Future<void> initialize() async {
    final rules = await _repository.getParserRules();
    if (rules.isNotEmpty) _parser.updateRules(rules);

    await NotificationService.instance.initialize();
    NotificationService.instance.onForegroundDecision = _applyDecision;
    await IngestBridge.instance.initialize();
    await _gmail.initialize(_database);

    IngestBridge.instance.stream.listen(_handleIngestEvent);
    _listening = true;

    WidgetsBinding.instance.addObserver(this);
    _startNotificationActionDrain();

    // Pull in anything captured while the app was closed, then verify access.
    await _drainPending();
    await _drainNotificationActions();
    await refreshNotificationAccess();
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onResumed();
    }
  }

  Future<void> _onResumed() async {
    await refreshNotificationAccess();
    await _drainPending();
    await _drainNotificationActions();
    // Background quick-replies write straight to SQLite; reload so Home/Inbox
    // reflect confirmed/ignored items when returning from the shade.
    notifyListeners();
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

  void _startNotificationActionDrain() {
    _notificationDrainTimer?.cancel();
    _notificationDrainTimer = Timer.periodic(
      const Duration(milliseconds: 800),
      (_) => unawaited(_drainNotificationActionsIfQueued()),
    );
  }

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
    return enabled;
  }

  Future<void> _handleIngestEvent(IngestEvent event) async {
    if (event.text.trim().isEmpty) return;

    final parsed = _parser.parse(
      event.text,
      source: event.source,
      fallbackTime: event.timestamp,
    );
    if (parsed == null) return;

    final outcome = await _deduplicator.processIncoming(
      parsed: parsed,
      source: event.source,
      rawText: event.text,
      messageTime: event.timestamp,
    );

    // A brand-new capture: ping the user with a system notification so
    // they know something landed in their review inbox even if the app is in
    // the background. Skip stale backlog items when draining after a long gap.
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
    for (final msg in messages) {
      final parsed = _parser.parse(
        msg.body,
        source: TransactionSource.gmail,
        fallbackTime: msg.receivedAt,
      );
      if (parsed == null) continue;

      final outcome = await _deduplicator.processIncoming(
        parsed: parsed,
        source: TransactionSource.gmail,
        rawText: msg.body,
        messageTime: msg.receivedAt,
      );
      if (outcome.result == DedupResult.created ||
          outcome.result == DedupResult.merged) {
        count++;
      }
      final captured = outcome.transaction;
      if (outcome.result == DedupResult.created && captured != null) {
        await NotificationService.instance.showTransactionCaptured(captured);
      }
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

  @override
  void dispose() {
    _notificationDrainTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
