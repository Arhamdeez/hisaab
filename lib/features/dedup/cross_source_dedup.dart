import '../../models/transaction.dart';

/// Detects when a new alert describes the same payment already captured from
/// another channel (e.g. wallet push notification + email receipt).
abstract final class CrossSourceDedup {
  static const amountTolerance = 0.01;
  static const tightWindow = Duration(hours: 6);
  static const looseWindow = Duration(hours: 72);

  static Transaction? findMatch({
    required Iterable<Transaction> candidates,
    required TransactionSource incomingSource,
    required double amount,
    required TransactionType type,
    required DateTime messageTime,
    required String merchant,
  }) {
    for (final existing in candidates) {
      if (!_isDuplicateOf(
        existing: existing,
        incomingSource: incomingSource,
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
    required TransactionSource incomingSource,
    required double amount,
    required TransactionType type,
    required DateTime messageTime,
    required String merchant,
  }) {
    if (existing.source == incomingSource) return false;
    if (existing.type != type) return false;
    if ((existing.amount - amount).abs() > amountTolerance) return false;

    final gap = messageTime.difference(existing.capturedAt).abs();
    final merchantsMatch = _merchantsMatch(existing.merchant, merchant);

    // Known different merchants on the same day → separate payments.
    if (!merchantsMatch &&
        existing.merchant != 'Unknown' &&
        merchant != 'Unknown') {
      return false;
    }

    final window = merchantsMatch ? looseWindow : tightWindow;
    return gap <= window;
  }

  static bool _merchantsMatch(String a, String b) {
    final na = _normalizeMerchant(a);
    final nb = _normalizeMerchant(b);
    if (na.isEmpty || nb.isEmpty) return false;
    if (na == nb) return true;
    final shorter = na.length <= nb.length ? na : nb;
    final longer = na.length > nb.length ? na : nb;
    return shorter.length >= 3 && longer.contains(shorter);
  }

  static String _normalizeMerchant(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
