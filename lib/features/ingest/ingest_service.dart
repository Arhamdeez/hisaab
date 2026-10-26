import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../background_ingest.dart' show bgIngestDirtyKey;
import '../../core/data/icloud_backup.dart';
import '../../core/repositories/transaction_repository.dart';
import '../../models/transaction.dart';
import '../notifications/notification_service.dart';
import 'ingest_processor.dart';
import 'ingest_bridge.dart';
import 'shortcuts_ingest.dart';

typedef TransactionRefreshCallback = Future<void> Function();

class IngestService extends ChangeNotifier with WidgetsBindingObserver {
  IngestService({
    required TransactionRepository repository,
    this.onTransactionsChanged,
  })  : _repository = repository,
        _processor = IngestProcessor(repository: repository);

  /// Called after captures are saved so transaction lists refresh immediately.
  TransactionRefreshCallback? onTransactionsChanged;

  final TransactionRepository _repository;
  final IngestProcessor _processor;

  bool _listening = false;
  bool _notificationAccess = false;
  bool _batteryUnrestricted = true;
  bool _appInForeground = true;
  Timer? _foregroundSafetyTimer;
  DateTime? _lastSmsRescanAt;

  static const _smsRescanCooldown = Duration(minutes: 5);
  static const _foregroundDrainInterval = Duration(minutes: 15);
  static const _smsHistoryBackfillKey = 'sms_history_backfill_v1';
  static const _smsHistoryLookback = Duration(days: 400);
  static const _smsHistoryMaxRows = 2500;

  bool get isListening => _listening;
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

    if (Platform.isAndroid) {
      await IngestBridge.instance.initialize();
    }

    _listening = true;

    WidgetsBinding.instance.addObserver(this);

    if (Platform.isIOS) {
      // Shortcuts deep links (hisaab://import?text=…) — Android path unchanged.
      await IcloudBackup.includeSqliteInBackup();
      await ShortcutsIngest.instance.start(_handleIngestEvent);
      await _drainNotificationActionsIfQueued();
      await _notifyTransactionDataChanged();
      return;
    }

    _startForegroundSafetyTimer();

    // After a reinstall, pull wallet/bank SMS history once so older alerts
    // can rebuild the ledger. Everyday launches stay on the short window.
    final prefs = await SharedPreferences.getInstance();
    final needsHistoryBackfill =
        !(prefs.getBool(_smsHistoryBackfillKey) ?? false);
    await _scanAndDrain(
      includeSmsRescan: true,
      walletSmsOnly: !needsHistoryBackfill,
      rescanShade: true,
      forceShadeScan: true,
      smsLookback: needsHistoryBackfill ? _smsHistoryLookback : null,
      smsMaxRows: needsHistoryBackfill ? _smsHistoryMaxRows : null,
    );
    if (needsHistoryBackfill) {
      final sms = await Permission.sms.status;
      if (sms.isGranted || sms.isLimited) {
        await prefs.setBool(_smsHistoryBackfillKey, true);
      }
    }
    await _drainNotificationActionsIfQueued();
    await refreshNotificationAccess();
    await refreshBatteryOptimization();
    await _notifyTransactionDataChanged();
  }

  /// Feeds one Shortcuts / deep-link capture through the same parser as Android.
  Future<bool> ingestShortcutText(
    String text, {
    String? title,
    TransactionSource source = TransactionSource.sms,
    DateTime? timestamp,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    final event = IngestEvent(
      text: trimmed,
      source: source,
      timestamp: timestamp ?? DateTime.now(),
      notificationTitle: title?.trim().isEmpty == true ? null : title?.trim(),
    );
    final ok = await _processor.processLiveEvent(event);
    await _notifyTransactionDataChanged();
    return ok;
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
    Duration? smsLookback,
    int? smsMaxRows,
  }) async {
    if (rescanShade) {
      await IngestBridge.instance.scanActiveNotifications(force: forceShadeScan);
    }
    if (includeSmsRescan && Platform.isAndroid) {
      final sms = await Permission.sms.status;
      if (sms.isGranted || sms.isLimited) {
        await IngestBridge.instance.scanRecentSms(
          walletShortCodesOnly: walletSmsOnly,
          lookback: smsLookback,
          maxRows: smsMaxRows,
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
    if (Platform.isIOS) {
      await ShortcutsIngest.instance.drainPending();
      await _drainNotificationActionsIfQueued();
      await _notifyTransactionDataChanged();
      return;
    }

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

    // Background ingest can write rows and clear the native queue while the UI
    // isolate is suspended. Always reload so Home / Transactions show them
    // without requiring pull-to-refresh.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(bgIngestDirtyKey, false);
    await _notifyTransactionDataChanged();
  }

  Future<void> _onBackground() async {
    try {
      await _repository.database
          .customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (_) {
      // The phone backup still copies the last flushed database file.
    }
    if (!Platform.isAndroid) return;
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

  Future<void> openBatteryOptimizationSettings() =>
      IngestBridge.instance.openBatteryOptimizationSettings();

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

  Future<NotificationAccessOpenResult> openNotificationSettings() =>
      IngestBridge.instance.openNotificationAccessSettings();

  Future<bool> hasNotificationAccess() =>
      IngestBridge.instance.isNotificationAccessEnabled();

  @override
  void dispose() {
    _foregroundSafetyTimer?.cancel();
    _ingestSubscription?.cancel();
    unawaited(ShortcutsIngest.instance.dispose());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
