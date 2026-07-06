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

typedef TransactionRefreshCallback = Future<void> Function();

class IngestService extends ChangeNotifier with WidgetsBindingObserver {
  IngestService({
    required TransactionRepository repository,
    required AppDatabase database,
    required GmailService gmailService,
    this.onTransactionsChanged,
  })  : _repository = repository,
        _processor = IngestProcessor(repository: repository),
        _gmail = gmailService,
        _database = database;

  /// Called after captures are saved so transaction lists refresh immediately.
  TransactionRefreshCallback? onTransactionsChanged;

  final TransactionRepository _repository;
  final IngestProcessor _processor;
  final GmailService _gmail;
  final AppDatabase _database;

  bool _listening = false;
  bool _notificationAccess = false;
  bool _batteryUnrestricted = true;
  bool _appInForeground = true;
  Timer? _foregroundSafetyTimer;
  DateTime? _lastSmsRescanAt;

  static const _smsRescanCooldown = Duration(minutes: 5);
  static const _foregroundDrainInterval = Duration(minutes: 15);

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

    // Cold start: shade scan + recent wallet SMS (8558, 3737, …), then drain queue.
    await _scanAndDrain(
      includeSmsRescan: true,
      walletSmsOnly: true,
      rescanShade: true,
      forceShadeScan: true,
    );
    await _drainNotificationActionsIfQueued();
    await refreshNotificationAccess();
    await refreshBatteryOptimization();
    await _notifyTransactionDataChanged();
  }

  Future<void> _notifyTransactionDataChanged() async {
    final refresh = onTransactionsChanged;
    if (refresh != null) {
      await refresh();
    }
    notifyListeners();
  }

  /// Scans the notification shade and drains the native capture queue.
  Future<void> syncCaptures() => _scanAndDrain(
        rescanShade: true,
        forceShadeScan: true,
        includeSmsRescan: true,
        walletSmsOnly: false,
      );

  /// [rescanShade] — re-read the notification panel (expensive; not every resume).
  /// [includeSmsRescan] — SMS inbox backfill.
  /// [walletSmsOnly] — when true, only scan known wallet short codes (3737, 8558, …).
  Future<void> _scanAndDrain({
    bool includeSmsRescan = false,
    bool walletSmsOnly = true,
    bool rescanShade = false,
    bool forceShadeScan = false,
  }) async {
    if (rescanShade) {
      await IngestBridge.instance.scanActiveNotifications(force: forceShadeScan);
    }
    if (includeSmsRescan && Platform.isAndroid) {
      final sms = await Permission.sms.status;
      if (sms.isGranted || sms.isLimited) {
        await IngestBridge.instance.scanRecentSms(
          walletShortCodesOnly: walletSmsOnly,
        );
        _lastSmsRescanAt = DateTime.now();
      }
    }
    await _drainPendingQueue();
  }

  /// Drains the native queue only when something is waiting — cheap idle check.
  Future<void> _drainPendingQueue() async {
    if (!await IngestBridge.instance.hasPendingCaptures()) return;
    await _processor.processPendingQueue();
    await _notifyTransactionDataChanged();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _appInForeground = true;
        unawaited(_onResumed());
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _appInForeground = false;
        unawaited(_onBackground());
      case AppLifecycleState.detached:
        _appInForeground = false;
        _foregroundSafetyTimer?.cancel();
      case AppLifecycleState.inactive:
        break;
    }
  }

  Future<void> _onResumed() async {
    // Live EventChannel handles captures while the app is open — no need for
    // the foreground keep-alive service until the user leaves.
    await IngestBridge.instance.stopKeepAlive();
    await refreshNotificationAccess();
    await refreshBatteryOptimization();
    await IngestBridge.instance.requestNotificationRebind();

    final smsDue = _lastSmsRescanAt == null ||
        DateTime.now().difference(_lastSmsRescanAt!) >= _smsRescanCooldown;
    if (smsDue) {
      await _scanAndDrain(
        includeSmsRescan: true,
        walletSmsOnly: true,
        rescanShade: false,
      );
    } else {
      await _drainPendingQueue();
    }
    await _drainNotificationActionsIfQueued();
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
    if (changed) await _notifyTransactionDataChanged();
  }

  /// Light failsafe while the app is open — live ingest is primary; this only
  /// drains a non-empty native queue (no SMS/shade rescans).
  void _startForegroundSafetyTimer() {
    _foregroundSafetyTimer?.cancel();
    _foregroundSafetyTimer =
        Timer.periodic(_foregroundDrainInterval, (_) async {
      if (!_appInForeground) return;
      await _drainPendingQueue();
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

    if (notifAccess && !_appInForeground) {
      await IngestBridge.instance.requestNotificationRebind();
      await IngestBridge.instance.startKeepAlive();
    } else if (notifAccess) {
      await IngestBridge.instance.requestNotificationRebind();
      await IngestBridge.instance.stopKeepAlive();
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
    if (changed) await _notifyTransactionDataChanged();
  }

  Future<void> _handleIngestEvent(IngestEvent event) async {
    if (event.text.trim().isEmpty) return;
    await _processor.processLiveEvent(event);
    await _notifyTransactionDataChanged();
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
    await _notifyTransactionDataChanged();
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
