import '../../models/transaction.dart';
import '../parser/transaction_parser.dart';
import 'burst_dedup.dart';

/// Collapses the exact same alert re-read from a shade scan, SMS inbox rescan,
/// or queue drain — without blocking legitimate cross-channel pairs (app + SMS).
abstract final class RescanDedup {
  static const amountTolerance = 0.01;
  static const minContentLength = 36;

  /// Normalizes alert bodies so whitespace-only differences still match.
  static String normalizeContent(String raw) {
    return raw.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
  }

  static Transaction? findMatch({
    required Iterable<Transaction> candidates,
    required double amount,
    required TransactionType type,
    required String rawText,
    String? referenceId,
  }) {
    final contentKey = normalizeContent(rawText);
    final hasContentKey =
        contentKey.length >= minContentLength;

    for (final existing in candidates) {
      if (existing.type != type) continue;
      if ((existing.amount - amount).abs() > amountTolerance) continue;
      if (BurstDedup.referencesConflict(referenceId, existing)) continue;

      if (referenceId != null && referenceId.isNotEmpty) {
        final existingRef =
            TransactionParser.extractReferenceId(existing.rawText ?? '');
        if (existingRef != null &&
            existingRef.isNotEmpty &&
            existingRef == referenceId) {
          return existing;
        }
      }

      if (hasContentKey) {
        final existingRaw = existing.rawText;
        if (existingRaw != null &&
            normalizeContent(existingRaw) == contentKey) {
          return existing;
        }
      }
    }
    return null;
  }
}
