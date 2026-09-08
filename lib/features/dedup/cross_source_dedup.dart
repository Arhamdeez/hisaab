import '../../models/transaction.dart';
import 'burst_dedup.dart';

/// Detects when a new alert describes the same payment already captured from
/// another channel (e.g. wallet push notification + email receipt + bank SMS).
///
/// Channels often label the same payment very differently — the app push may
/// show the counterparty's name, the email shows the wallet brand, and the SMS
/// shows a masked account number. So matching falls back through three signals,
/// strongest first:
///   1. Same transaction time ([occurredAt]) to the minute — almost certainly
///      the same payment reported twice, regardless of the merchant label.
///   2. Compatible merchant names within a loose delivery window.
///   3. One side is a generic wallet/bank label within a medium window.
abstract final class CrossSourceDedup {
  static const amountTolerance = 0.01;

  /// When both channels agree on the exact transaction time, treat them as the
  /// same payment even if the merchant labels disagree.
  static const sameMomentWindow = Duration(minutes: 3);

  static const tightWindow = Duration(hours: 6);
  static const genericWindow = Duration(hours: 48);
  static const looseWindow = Duration(hours: 72);

  static Transaction? findMatch({
    required Iterable<Transaction> candidates,
    required TransactionSource incomingSource,
    required double amount,
    required TransactionType type,
    required DateTime messageTime,
    required DateTime occurredAt,
    required String merchant,
    String? referenceId,
  }) {
    Transaction? strong;
    final genericHits = <Transaction>[];

    for (final existing in candidates) {
      if (!_baseCompatible(
        existing: existing,
        incomingSource: incomingSource,
        amount: amount,
        type: type,
        referenceId: referenceId,
      )) {
        continue;
      }

      if (BurstDedup.referencesMatch(referenceId, existing)) {
        return existing;
      }

      if (occurredAt.difference(existing.occurredAt).abs() <= sameMomentWindow) {
        strong ??= existing;
        continue;
      }

      if (!BurstDedup.paymentAlertsLikelySame(existing.merchant, merchant)) {
        continue;
      }

      final gap = messageTime.difference(existing.capturedAt).abs();
      final namesAgree =
          BurstDedup.merchantsCompatible(existing.merchant, merchant);
      final oneGeneric = BurstDedup.isGenericInstitution(existing.merchant) ||
          BurstDedup.isGenericInstitution(merchant);
      final window = namesAgree
          ? looseWindow
          : oneGeneric
              ? genericWindow
              : tightWindow;
      if (gap > window) continue;

      if (namesAgree) {
        strong ??= existing;
      } else {
        genericHits.add(existing);
      }
    }

    if (strong != null) return strong;
    // Bare "You paid PKR 15,000" emails have no payee. Merge only when there
    // is a single same-amount candidate — two 15k payments would be ambiguous.
    if (genericHits.length == 1) return genericHits.single;
    return null;
  }

  static bool _baseCompatible({
    required Transaction existing,
    required TransactionSource incomingSource,
    required double amount,
    required TransactionType type,
    String? referenceId,
  }) {
    if (existing.source == incomingSource) return false;
    if (existing.type != type) return false;
    if ((existing.amount - amount).abs() > amountTolerance) return false;
    if (BurstDedup.referencesConflict(referenceId, existing)) return false;
    return true;
  }
}
