import '../../models/transaction.dart';
import '../parser/transaction_parser.dart';

/// Decides whether a captured alert needs manual review in the Inbox.
abstract final class ReviewPolicy {
  static const backToBackWindow = Duration(minutes: 3);
  static const amountTolerance = 0.01;

  static final _selfTransferPhrases = RegExp(
    r'own account|self[\s-]?transfer|between your accounts|to yourself|'
    r'sent to yourself|transfer to self|own a/c|same account',
    caseSensitive: false,
  );

  /// True when sender and receiver look like the same person, or the message
  /// explicitly describes a self-transfer.
  static bool sameSenderAndReceiver({
    required ParsedTransaction parsed,
    required String rawText,
  }) {
    if (_selfTransferPhrases.hasMatch(rawText)) return true;

    final sender = parsed.senderName;
    final receiver = parsed.receiverName;
    if (sender == null || receiver == null) return false;
    return _namesMatch(sender, receiver);
  }

  static Iterable<Transaction> _recentCaptures(
    DateTime messageTime,
    Iterable<Transaction> recent,
  ) {
    return recent.where(
      (tx) => messageTime.difference(tx.capturedAt).abs() <= backToBackWindow,
    );
  }

  /// True when an opposite-type transaction for the same amount arrived within
  /// [backToBackWindow] — typical of moving money between your own accounts.
  static bool isBackToBackTransfer({
    required ParsedTransaction incoming,
    required DateTime messageTime,
    required Iterable<Transaction> recent,
  }) {
    final opposite = incoming.type == TransactionType.debit
        ? TransactionType.credit
        : TransactionType.debit;

    for (final tx in _recentCaptures(messageTime, recent)) {
      if (tx.type != opposite) continue;
      if ((tx.amount - incoming.amount).abs() > amountTolerance) continue;
      return true;
    }
    return false;
  }

  static bool requiresReview({
    required ParsedTransaction parsed,
    required String rawText,
    required DateTime messageTime,
    required Iterable<Transaction> recent,
  }) {
    return sameSenderAndReceiver(parsed: parsed, rawText: rawText) ||
        isBackToBackTransfer(
          incoming: parsed,
          messageTime: messageTime,
          recent: recent,
        );
  }

  /// Finds the opposite leg of a likely own-account transfer.
  static Transaction? matchingTransferLeg({
    required ParsedTransaction incoming,
    required DateTime messageTime,
    required Iterable<Transaction> recent,
  }) {
    final opposite = incoming.type == TransactionType.debit
        ? TransactionType.credit
        : TransactionType.debit;

    Transaction? best;
    Duration? bestGap;

    for (final tx in _recentCaptures(messageTime, recent)) {
      if (tx.type != opposite) continue;
      if ((tx.amount - incoming.amount).abs() > amountTolerance) continue;

      final gap = messageTime.difference(tx.capturedAt).abs();
      if (bestGap == null || gap < bestGap) {
        best = tx;
        bestGap = gap;
      }
    }
    return best;
  }

  static bool _namesMatch(String a, String b) {
    final na = _normalizeName(a);
    final nb = _normalizeName(b);
    if (na.isEmpty || nb.isEmpty) return false;
    if (na == nb) return true;

    // "Arham" vs "Muhammad Arham Babar" — same person if one contains the other.
    final shorter = na.length <= nb.length ? na : nb;
    final longer = na.length > nb.length ? na : nb;
    if (shorter.length >= 3 && longer.contains(shorter)) return true;
    return false;
  }

  static String _normalizeName(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
