import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/app_database.dart' hide Transaction;
import '../../core/repositories/transaction_repository.dart';
import '../../core/utils/formatters.dart';
import '../../models/transaction.dart';

/// Action ids shared between the posted notification and the response handler.
const _acceptActionId = 'accept_txn';
const _rejectActionId = 'reject_txn';

/// SharedPreferences key holding a JSON queue of notification actions that were
/// triggered while the app was fully terminated (so no live isolate could
/// apply them immediately).
const _pendingActionsKey = 'pending_notification_actions';

/// Parsed, app-agnostic form of a notification action response.
class NotificationDecision {
  const NotificationDecision({
    required this.id,
    required this.accept,
    this.note,
    this.isDebit = true,
  });

  final String id;
  final bool accept;
  final String? note;

  /// Whether the captured transaction was a debit (spend). Encoded in the
  /// notification payload so accept can skip a DB read for category inference.
  final bool isDebit;
}

/// Handles notification action responses delivered to a background isolate.
///
/// Android routes action buttons here even when the app is alive. Keep this path
/// fast: write to SQLite and return so the inline-reply spinner clears immediately.
/// Must be a top-level function annotated for the AOT compiler.
@pragma('vm:entry-point')
Future<void> notificationBackgroundHandler(NotificationResponse response) async {
  await NotificationService.handleBackgroundResponse(response);
}

/// Posts on-device notifications for newly captured transactions.
///
/// Normal payments get a simple "logged" heads-up.
/// Own-account / self-transfers get plain Accept / Reject actions so the user
/// can confirm before they count toward spending.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _channelId = 'captured_transactions';
  static const _channelName = 'Payment tracking';
  static const _channelDescription =
      'Alerts when HISAAB logs a payment, and Accept/Reject for self-transfers.';
  static const _iosCategoryReview = 'txn_self_transfer_review';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Fast path: invoked (in the main isolate) when an action is handled while
  /// the app is alive, so the listener can apply it directly without the queue.
  Future<void> Function(NotificationDecision decision)? onForegroundDecision;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          _iosCategoryReview,
          actions: [
            DarwinNotificationAction.plain(_acceptActionId, 'Accept'),
            DarwinNotificationAction.plain(
              _rejectActionId,
              'Reject',
              options: {DarwinNotificationActionOption.destructive},
            ),
          ],
        ),
      ],
    );

    try {
      await _plugin.initialize(
        settings: InitializationSettings(
          android: androidInit,
          iOS: darwinInit,
          macOS: darwinInit,
        ),
        onDidReceiveNotificationResponse: _onForegroundResponse,
        onDidReceiveBackgroundNotificationResponse:
            notificationBackgroundHandler,
      );

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        await android.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
          ),
        );
      }

      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  /// Asks the OS for permission to post notifications (Android 13+ / iOS).
  Future<bool> requestPermission() async {
    try {
      if (Platform.isAndroid) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final granted = await android?.requestNotificationsPermission();
        return granted ?? false;
      }
      if (Platform.isIOS || Platform.isMacOS) {
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final granted = await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('NotificationService permission error: $e');
    }
    return false;
  }

  /// Shows a quick heads-up when a payment is logged (direction-aware copy).
  Future<void> showTransactionCaptured(Transaction transaction) async {
    if (!_initialized) await initialize();
    if (!_initialized) return;

    if (transaction.isPending) {
      await _showReviewNotification(transaction);
      return;
    }

    final copy = _captureAlertCopy(transaction);

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      category: AndroidNotificationCategory.status,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    );

    try {
      await _plugin.show(
        id: _notificationIdFor(transaction.id),
        title: copy.title,
        body: copy.body,
        notificationDetails: const NotificationDetails(
          android: androidDetails,
          iOS: darwinDetails,
          macOS: darwinDetails,
        ),
      );
    } catch (e) {
      debugPrint('NotificationService show error: $e');
    }
  }

  /// Own-account transfers only — plain Accept / Reject, no text input.
  Future<void> _showReviewNotification(Transaction transaction) async {
    final copy = _reviewAlertCopy(transaction);
    final payload = _payloadFor(transaction);

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
      actions: const [
        AndroidNotificationAction(
          _acceptActionId,
          'Accept',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          _rejectActionId,
          'Reject',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );
    const darwinDetails = DarwinNotificationDetails(
      categoryIdentifier: _iosCategoryReview,
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    try {
      await _plugin.show(
        id: _notificationIdFor(transaction.id),
        title: copy.title,
        body: copy.body,
        notificationDetails: NotificationDetails(
          android: androidDetails,
          iOS: darwinDetails,
          macOS: darwinDetails,
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('NotificationService review show error: $e');
    }
  }

  static String _payloadFor(Transaction transaction) =>
      '${transaction.id}|${transaction.isDebit ? 'd' : 'c'}';

  /// Title + body for a newly captured transaction.
  static ({String title, String body}) _captureAlertCopy(
    Transaction transaction,
  ) {
    final amount = formatCurrency(transaction.amount);
    final merchant = transaction.merchant;

    if (transaction.isDebit) {
      return (
        title: 'Gone.',
        body: '−$amount to $merchant',
      );
    }
    return (
      title: 'Got it.',
      body: '+$amount from $merchant',
    );
  }

  static ({String title, String body}) _reviewAlertCopy(
    Transaction transaction,
  ) {
    final amount = formatCurrency(transaction.amount);
    final merchant = transaction.merchant;

    if (transaction.isDebit) {
      return (
        title: 'Own-account transfer?',
        body: '−$amount to $merchant — Accept to count, Reject to skip',
      );
    }
    return (
      title: 'Own-account transfer?',
      body: '+$amount from $merchant — Accept to count, Reject to skip',
    );
  }

  void _onForegroundResponse(NotificationResponse response) {
    final decision = _parse(response);
    if (decision == null) {
      debugPrint(
        'NotificationService ignored response '
        'action=${response.actionId} payload=${response.payload}',
      );
      return;
    }

    unawaited(_dismiss(decision.id));
    final handler = onForegroundDecision;
    if (handler != null) {
      unawaited(
        handler(decision).then((_) => _removePendingForId(decision.id)),
      );
    } else {
      unawaited(_enqueue(decision));
    }
  }

  /// Applies a single decision to [repository].
  /// Accept confirms (counts the transfer); Reject ignores it.
  Future<bool> applyDecision(
    TransactionRepository repository,
    NotificationDecision decision, {
    bool fast = false,
  }) async {
    try {
      if (!decision.accept) {
        return repository.applyReview(
          decision.id,
          status: TransactionStatus.ignored,
        );
      }

      // Self-transfer accept: just confirm. Category stays as parsed / Other.
      return repository.applyReview(
        decision.id,
        status: TransactionStatus.confirmed,
      );
    } catch (e) {
      debugPrint('NotificationService apply error: $e');
      return false;
    }
  }

  /// Parses a raw response into a [NotificationDecision], or null if it isn't
  /// one of our actions.
  static NotificationDecision? _parse(NotificationResponse response) {
    final raw = response.payload;
    if (raw == null || raw.isEmpty) return null;
    final actionId = response.actionId;
    if (actionId != _acceptActionId && actionId != _rejectActionId) {
      return null;
    }

    // Payload is "txnId" or "txnId|c" for credit / "txnId|d" for debit.
    final parts = raw.split('|');
    final id = parts.first;
    if (id.isEmpty) return null;
    final isDebit = parts.length < 2 || parts[1] != 'c';

    return NotificationDecision(
      id: id,
      accept: actionId == _acceptActionId,
      note: response.input,
      isDebit: isDebit,
    );
  }

  /// Background-isolate entry: persist to SQLite immediately so Android clears
  /// the inline-reply loading state, then queue only if the write failed.
  static Future<void> handleBackgroundResponse(
    NotificationResponse response,
  ) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    final decision = _parse(response);
    if (decision == null) {
      debugPrint(
        'NotificationService background ignored response '
        'action=${response.actionId} payload=${response.payload}',
      );
      return;
    }

    var applied = false;
    try {
      final database = AppDatabase();
      try {
        applied = await NotificationService.instance.applyDecision(
          TransactionRepository(database),
          decision,
          fast: true,
        );
        debugPrint(
          'NotificationService background '
          '${decision.accept ? 'accept' : 'reject'} '
          '${decision.id} applied=$applied',
        );
      } finally {
        await database.close();
      }
    } catch (e) {
      debugPrint('NotificationService background apply error: $e');
    }

    if (!applied) {
      await _enqueue(decision);
    }

    unawaited(_dismiss(decision.id));
  }

  /// Persists a decision so the app can apply it on next launch/resume. Used as
  /// a fallback when the direct background write isn't possible.
  static Future<void> _enqueue(NotificationDecision decision) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_pendingActionsKey) ?? <String>[];
      raw.removeWhere((entry) {
        try {
          final map = jsonDecode(entry) as Map<String, dynamic>;
          return map['id'] == decision.id;
        } catch (_) {
          return false;
        }
      });
      raw.add(jsonEncode({
        'id': decision.id,
        'action': decision.accept ? 'accept' : 'reject',
        'note': decision.note ?? '',
        'isDebit': decision.isDebit,
      }));
      await prefs.setStringList(_pendingActionsKey, raw);
    } catch (e) {
      debugPrint('NotificationService enqueue error: $e');
    }
  }

  static Future<void> _removePendingForId(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_pendingActionsKey) ?? <String>[];
      if (raw.isEmpty) return;
      final next = raw.where((entry) {
        try {
          final map = jsonDecode(entry) as Map<String, dynamic>;
          return map['id'] != id;
        } catch (_) {
          return true;
        }
      }).toList();
      if (next.length == raw.length) return;
      if (next.isEmpty) {
        await prefs.remove(_pendingActionsKey);
      } else {
        await prefs.setStringList(_pendingActionsKey, next);
      }
    } catch (e) {
      debugPrint('NotificationService dequeue error: $e');
    }
  }

  /// True when quick-reply actions are waiting for the main isolate to apply.
  static Future<bool> hasPendingActions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_pendingActionsKey);
      return raw != null && raw.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Drains decisions queued while the app was terminated and applies them.
  /// Returns true if anything changed (so callers can refresh the UI).
  Future<bool> drainPendingActions(TransactionRepository repository) async {
    List<String> raw;
    try {
      final prefs = await SharedPreferences.getInstance();
      raw = prefs.getStringList(_pendingActionsKey) ?? <String>[];
      if (raw.isEmpty) return false;
      await prefs.remove(_pendingActionsKey);
    } catch (e) {
      debugPrint('NotificationService drain read error: $e');
      return false;
    }

    var changed = false;
    for (final entry in raw) {
      try {
        final map = jsonDecode(entry) as Map<String, dynamic>;
        final id = map['id'] as String?;
        if (id == null) continue;
        final note = (map['note'] as String?) ?? '';
        final applied = await applyDecision(
          repository,
          NotificationDecision(
            id: id,
            accept: map['action'] == 'accept',
            note: note,
            isDebit: map['isDebit'] as bool? ?? true,
          ),
          fast: true,
        );
        changed = changed || applied;
      } catch (e) {
        debugPrint('NotificationService drain apply error: $e');
      }
    }
    return changed;
  }

  /// Notification id derived from a transaction id.
  static int _notificationIdFor(String transactionId) =>
      transactionId.hashCode & 0x7fffffff;

  /// Cancels the posted notification for [transactionId]. Works from either the
  /// foreground or a background isolate via a local plugin instance.
  static Future<void> _dismiss(String transactionId) async {
    try {
      await FlutterLocalNotificationsPlugin()
          .cancel(id: _notificationIdFor(transactionId));
    } catch (e) {
      debugPrint('NotificationService dismiss error: $e');
    }
  }
}
