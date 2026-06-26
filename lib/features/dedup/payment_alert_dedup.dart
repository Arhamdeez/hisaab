import '../../models/transaction.dart';
import 'burst_dedup.dart';

/// Merges the same payment when it arrives twice through similar channels
/// (e.g. wallet app push + Gmail app notification — both [notification] source).
abstract final class PaymentAlertDedup {
  static const amountTolerance = 0.01;
  static const window = Duration(hours: 3);

  static Transaction? findMatch({
    required Iterable<Transaction> candidates,
    required double amount,
    required TransactionType type,
    required DateTime messageTime,
    required String merchant,
  }) {
    for (final existing in candidates) {
      if (!_isDuplicateOf(
        existing: existing,
        amount: amount,
        type: type,
        messageTime: messageTime,
        merchant: merchant,
      )) {
        continue;
      }
      return existing;
    }
    return null;
  }

  static bool _isDuplicateOf({
    required Transaction existing,
    required double amount,
    required TransactionType type,
    required DateTime messageTime,
    required String merchant,
  }) {
    if (existing.type != type) return false;
    if ((existing.amount - amount).abs() > amountTolerance) return false;
    if (!BurstDedup.paymentAlertsLikelySame(existing.merchant, merchant)) {
      return false;
    }

    final gap = messageTime.difference(existing.capturedAt).abs();
    return gap <= window;
  }
}
