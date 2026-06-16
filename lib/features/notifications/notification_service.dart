import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/app_database.dart' show AppDatabase;
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
/// Notification action buttons (with no UI) are ALWAYS routed here by Android —
/// even when the app is alive — so to apply the typed note immediately we open
/// the database right here and write it, rather than only queueing for later.
/// Must be a top-level function annotated for the AOT compiler.
@pragma('vm:entry-point')
Future<void> notificationBackgroundHandler(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await NotificationService.handleBackgroundResponse(response);
}

/// Posts on-device notifications for newly captured transactions, with quick
/// "Accept" (inline reply) and "Reject" actions so the user can triage without
/// opening the app. The reply prompt adapts to money out vs money in.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _channelId = 'captured_transactions';
  static const _channelName = 'Captured transactions';
  static const _channelDescription =
      'Alerts when a new payment is detected and added to your review inbox.';
  static const _iosCategoryDebit = 'txn_review_out';
  static const _iosCategoryCredit = 'txn_review_in';

  static const _outPrompt = 'Where did this money go?';
  static const _inPrompt = 'Where did this money come from?';

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
          _iosCategoryDebit,
          actions: _darwinActions(_outPrompt),
        ),
        DarwinNotificationCategory(
          _iosCategoryCredit,
          actions: _darwinActions(_inPrompt),
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

  List<DarwinNotificationAction> _darwinActions(String prompt) => [
        DarwinNotificationAction.text(
          _acceptActionId,
          'Accept',
          buttonTitle: 'Save',
          placeholder: prompt,
        ),
        DarwinNotificationAction.plain(
          _rejectActionId,
          'Reject',
          options: {DarwinNotificationActionOption.destructive},
        ),
      ];

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

  /// Shows a system notification for a newly captured transaction. The reply
  /// prompt and copy adapt to whether money went out or came in.
  Future<void> showTransactionCaptured(Transaction transaction) async {
    if (!_initialized) await initialize();
    if (!_initialized) return;

    final isDebit = transaction.isDebit;
    final amount = formatCurrency(transaction.amount);
    final sign = isDebit ? '−' : '+';
    final title = isDebit ? 'Payment detected' : 'Money received';
    final body = '$sign$amount · ${transaction.merchant}';
    final prompt = isDebit ? _outPrompt : _inPrompt;

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.recommendation,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          _acceptActionId,
          'Accept',
          inputs: [AndroidNotificationActionInput(label: prompt)],
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          _rejectActionId,
          'Reject',
          cancelNotification: true,
        ),
      ],
    );
    final darwinDetails = DarwinNotificationDetails(
      categoryIdentifier: isDebit ? _iosCategoryDebit : _iosCategoryCredit,
    );

    try {
      await _plugin.show(
        id: _notificationIdFor(transaction.id),
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: androidDetails,
          iOS: darwinDetails,
          macOS: darwinDetails,
        ),
        payload: _payloadFor(transaction),
      );
    } catch (e) {
      debugPrint('NotificationService show error: $e');
    }
  }

  void _onForegroundResponse(NotificationResponse response) async {
    final decision = _parse(response);
    if (decision == null) return;
    await _dismiss(decision.id);
    final handler = onForegroundDecision;
    if (handler != null) {
      await handler(decision);
    }
  }

  /// Applies a single decision to [repository] in one read + one write (accept)
  /// or a single write (reject). Returns true if anything changed.
  Future<bool> applyDecision(
    TransactionRepository repository,
    NotificationDecision decision,
  ) async {
    try {
      if (!decision.accept) {
        return repository.applyReview(
          decision.id,
          status: TransactionStatus.ignored,
        );
      }

      final note = decision.note?.trim();
      final hasNote = note != null && note.isNotEmpty;
      SpendingCategory? category;
      if (hasNote && decision.isDebit) {
        category = _inferCategory(note);
      }
      return repository.applyReview(
        decision.id,
        status: TransactionStatus.confirmed,
        merchant: hasNote ? note : null,
        category: category,
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

  static String _payloadFor(Transaction transaction) {
    final kind = transaction.isDebit ? 'd' : 'c';
    return '${transaction.id}|$kind';
  }

  /// Background-isolate entry: dismiss the notification, then apply the decision
  /// straight to the database so the typed note lands immediately. Falls back to
  /// the persisted queue if the direct write fails.
  static Future<void> handleBackgroundResponse(
    NotificationResponse response,
  ) async {
    final decision = _parse(response);
    if (decision == null) return;

    await _dismiss(decision.id);

    AppDatabase? db;
    try {
      db = AppDatabase();
      final repo = TransactionRepository(db);
      final applied = await instance.applyDecision(repo, decision);
      if (!applied) await _enqueue(decision);
    } catch (e) {
      debugPrint('NotificationService background apply error: $e');
      await _enqueue(decision);
    } finally {
      await db?.close();
    }
  }

  /// Persists a decision so the app can apply it on next launch/resume. Used as
  /// a fallback when the direct background write isn't possible.
  static Future<void> _enqueue(NotificationDecision decision) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getStringList(_pendingActionsKey) ?? <String>[];
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

  /// Drains decisions queued while the app was terminated and applies them.
  /// Returns true if anything changed (so callers can refresh the UI).
  Future<bool> drainPendingActions(TransactionRepository repository) async {
    List<String> raw;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
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

  /// Best-effort mapping from a free-text reply to a spending category.
  static SpendingCategory? _inferCategory(String note) {
    final text = note.toLowerCase();
    const keywords = <SpendingCategory, List<String>>{
      SpendingCategory.food: [
        'food', 'lunch', 'dinner', 'breakfast', 'grocery', 'groceries',
        'restaurant', 'cafe', 'coffee', 'snack', 'eat', 'meal',
      ],
      SpendingCategory.transport: [
        'transport', 'fuel', 'petrol', 'gas', 'uber', 'careem', 'taxi',
        'bus', 'train', 'ride', 'parking', 'travel',
      ],
      SpendingCategory.shopping: [
        'shopping', 'clothes', 'shoes', 'amazon', 'store', 'mall', 'shop',
      ],
      SpendingCategory.bills: [
        'bill', 'bills', 'rent', 'electric', 'electricity', 'water', 'gas bill',
        'internet', 'wifi', 'phone', 'utility', 'housing',
      ],
      SpendingCategory.entertainment: [
        'movie', 'cinema', 'game', 'netflix', 'spotify', 'fun', 'entertainment',
        'concert', 'party',
      ],
      SpendingCategory.health: [
        'health', 'doctor', 'medicine', 'pharmacy', 'hospital', 'gym',
        'clinic', 'medical',
      ],
    };

    for (final entry in keywords.entries) {
      for (final word in entry.value) {
        if (text.contains(word)) return entry.key;
      }
    }
    return null;
  }
}
