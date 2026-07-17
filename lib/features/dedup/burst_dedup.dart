import '../../models/transaction.dart';
import '../parser/transaction_parser.dart';

/// Collapses repeated wallet/bank alerts for the same payment within a short
/// window (same app channel, amount, type, and counterparty).
abstract final class BurstDedup {
  static const window = Duration(seconds: 30);
  static const amountTolerance = 0.01;

  /// True when the incoming alert and an existing transaction both carry a
  /// transaction reference id and they differ — a decisive signal that they are
  /// *different* payments, so they must never be merged regardless of how alike
  /// their amount, merchant, and timing look.
  static bool referencesConflict(String? incomingRef, Transaction existing) {
    if (incomingRef == null || incomingRef.isEmpty) return false;
    final existingRef =
        TransactionParser.extractReferenceId(existing.rawText ?? '');
    if (existingRef == null || existingRef.isEmpty) return false;
    return existingRef != incomingRef;
  }

  static const _unknownMerchants = {
    'unknown',
    'customer',
    'dearcustomer',
    'dear customer',
    'wallet',
    'account',
    'payment',
  };

  /// Wallet/bank branding in alerts — not a counterparty name.
  static final _institutionMerchants = RegExp(
    r'^(?:jazzcash|easypaisa|nayapay|sadapay|mobilink|ubl|hbl|mcb|'
    r'transaction alert|money transfer|money received|money sent|'
    r'payment received|transfer successful|successful transfer|'
    r'e statement|estatement|debit alert|credit alert|'
    r'off it goes|got money|you.?ve got money|transaction successful)$',
    caseSensitive: false,
  );

  static bool matches({
    required Transaction existing,
    required double amount,
    required TransactionType type,
    required TransactionSource source,
    required DateTime messageTime,
    required String merchant,
    String? referenceId,
  }) {
    if (existing.source != source) return false;
    if (existing.type != type) return false;
    if ((existing.amount - amount).abs() > amountTolerance) return false;
    if (referencesConflict(referenceId, existing)) return false;

    final gap = messageTime.difference(existing.capturedAt).abs();
    if (gap > window) return false;

    return merchantsCompatible(existing.merchant, merchant);
  }

  /// True when one side is a wallet/bank label rather than a person or shop.
  static bool isGenericInstitution(String merchant) {
    final n = _normalizeMerchant(merchant);
    if (n.isEmpty || _unknownMerchants.contains(n)) return true;
    return _institutionMerchants.hasMatch(n);
  }

  /// Same payment across app push + email/SMS when merchants differ by channel.
  static bool paymentAlertsLikelySame(String a, String b) {
    if (merchantsCompatible(a, b)) return true;
    return isGenericInstitution(a) || isGenericInstitution(b);
  }

  static bool merchantsCompatible(String a, String b) {
    final na = _normalizeMerchant(a);
    final nb = _normalizeMerchant(b);
    if (na.isEmpty || nb.isEmpty) return true;
    if (na == nb) return true;
    if (_isUnknown(a) || _isUnknown(b)) return true;
    if (na.length >= 3 && nb.length >= 3) {
      if (na.contains(nb) || nb.contains(na)) return true;
    }
    return false;
  }

  static String pickBetterMerchant(String existing, String incoming) {
    final e = existing.trim();
    final i = incoming.trim();
    if (isGenericInstitution(e) && !isGenericInstitution(i) && !_isUnknown(i)) {
      return i;
    }
    if (isGenericInstitution(i) && !isGenericInstitution(e) && !_isUnknown(e)) {
      return e;
    }
    if (_isUnknown(e) && !_isUnknown(i)) return i;
    if (!_isUnknown(i) &&
        i.length > e.length &&
        (_isUnknown(e) || merchantsCompatible(e, i))) {
      return i;
    }
    return e;
  }

  static bool _isUnknown(String value) {
    final n = _normalizeMerchant(value);
    return n.isEmpty || _unknownMerchants.contains(n);
  }

  static String _normalizeMerchant(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
