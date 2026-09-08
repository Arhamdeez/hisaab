import '../../models/transaction.dart';
import 'burst_dedup.dart';

/// Merges the same payment when it arrives twice through similar channels
/// (e.g. wallet app push + Gmail app notification — both [notification] source).
abstract final class PaymentAlertDedup {
  static const amountTolerance = 0.01;
  static const window = Duration(hours: 3);
  static const genericWindow = Duration(hours: 48);

  static Transaction? findMatch({
    required Iterable<Transaction> candidates,
    required double amount,
    required TransactionType type,
    required DateTime messageTime,
    required String merchant,
    String? referenceId,
  }) {
    Transaction? strong;
    final genericHits = <Transaction>[];

    for (final existing in candidates) {
      if (existing.type != type) continue;
      if ((existing.amount - amount).abs() > amountTolerance) continue;
      if (BurstDedup.referencesConflict(referenceId, existing)) continue;
      if (BurstDedup.referencesMatch(referenceId, existing)) {
        return existing;
      }
      if (!BurstDedup.paymentAlertsLikelySame(existing.merchant, merchant)) {
        continue;
      }

      final gap = messageTime.difference(existing.capturedAt).abs();
      final namesAgree =
          BurstDedup.merchantsCompatible(existing.merchant, merchant);
      final oneGeneric = BurstDedup.isGenericInstitution(existing.merchant) ||
          BurstDedup.isGenericInstitution(merchant);
      final allowed = namesAgree
          ? window
          : oneGeneric
              ? genericWindow
              : window;
      if (gap > allowed) continue;

      if (namesAgree) {
        strong ??= existing;
      } else {
        genericHits.add(existing);
      }
    }

    if (strong != null) return strong;
    if (genericHits.length == 1) return genericHits.single;
    return null;
  }
}
