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
import 'ingest_processor.dart';
import 'gmail_service.dart';
import 'ingest_bridge.dart';

class IngestService extends ChangeNotifier with WidgetsBindingObserver {
  IngestService({
    required TransactionRepository repository,
    required AppDatabase database,
    required GmailService gmailService,
  })  : _repository = repository,
        _processor = IngestProcessor(repository: repository),
        _gmail = gmailService,
        _database = database;

  final TransactionRepository _repository;
  final IngestProcessor _processor;
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

    // Cold start: read the shade once, then drain the queue (SMS backfill on pull-to-refresh).
    await _scanAndDrain(includeSmsRescan: false, rescanShade: true);
    await _drainNotificationActionsIfQueued();
    await refreshNotificationAccess();
    await refreshBatteryOptimization();
    notifyListeners();
  }

  /// Scans the notification shade and drains the native capture queue.
  Future<void> syncCaptures() =>
      _scanAndDrain(rescanShade: true, includeSmsRescan: true);

  /// [rescanShade] — re-read the notification panel (expensive; not every resume).
  /// [includeSmsRescan] — SMS inbox backfill once per cold start only.
  Future<void> _scanAndDrain({
    bool includeSmsRescan = false,
    bool rescanShade = false,
  }) async {
    if (rescanShade) {
      await IngestBridge.instance.scanActiveNotifications();
    }
    if (includeSmsRescan && Platform.isAndroid) {
      final sms = await Permission.sms.status;
      if (sms.isGranted || sms.isLimited) {
        await IngestBridge.instance.scanRecentSms();
      }
    }
    await _processor.processPendingQueue();
    notifyListeners();
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
    // Only drain what arrived while backgrounded — do not re-read the whole shade.
    await _scanAndDrain(includeSmsRescan: false, rescanShade: false);
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

  /// Full rescan + drain every 5 min while the app is open (original failsafe).
  void _startForegroundSafetyTimer() {
    _foregroundSafetyTimer?.cancel();
    _foregroundSafetyTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      unawaited(_scanAndDrain(rescanShade: false));
    });
  }

  Future<void> _syncCapturePipeline() async {
    if (!Platform.isAndroid) return;

    final notifAccess = await IngestBridge.instance.isNotificationAccessEnabled();
    final smsGranted = (await Permission.sms.status).isGranted;

    if (!notifAccess && !smsGranted) {
      await IngestBridge.instance.stopKeepAlive();
      return;
    }

    if (notifAccess) {
      await IngestBridge.instance.requestNotificationRebind();
      // Keeps notification listener alive on Samsung — not needed for SMS-only.
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

  Future<void> _handleIngestEvent(IngestEvent event) async {
    if (event.text.trim().isEmpty) return;
    await _processor.processLiveEvent(event);
    notifyListeners();
  }

  /// Re-reads the OS notification-access state and notifies listeners on change.
  Future<bool> refreshNotificationAccess() async {
    final enabled = await IngestBridge.instance.isNotificationAccessEnabled();
    if (enabled != _notificationAccess) {
      _notificationAccess = enabled;
      notifyListeners();
    }
    await _syncCapturePipeline();
    return enabled;
  }

  Future<int> syncGmail() async {
    final messages = await _gmail.fetchTransactionEmails();
    var count = 0;
    final processedIds = <String>[];
    final parser = TransactionParser();
    final deduplicator = Deduplicator(_repository);
    for (final msg in messages) {
      final parsed = parser.parse(
        msg.body,
        source: TransactionSource.gmail,
        fallbackTime: msg.receivedAt,
      );
      processedIds.add(msg.id);
      if (parsed == null) continue;

      final outcome = await deduplicator.processIncoming(
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
