import '../../core/repositories/transaction_repository.dart';
import '../../models/transaction.dart';
import '../parser/transaction_parser.dart';

enum DedupResult { created, merged, skipped }

class Deduplicator {
  Deduplicator(this._repository);

  final TransactionRepository _repository;

  Future<DedupResult> processIncoming({
    required ParsedTransaction parsed,
    required TransactionSource source,
    required String rawText,
    required DateTime messageTime,
  }) async {
    final occurredAt = parsed.occurredAt ?? messageTime;
    final fingerprint = TransactionParser.buildFingerprint(
      amount: parsed.amount,
      occurredAt: occurredAt,
      merchant: parsed.merchant,
      accountRef: parsed.accountRef,
    );

    final existingInWindow = await _repository.getInDedupWindow(
      fingerprint: fingerprint,
      occurredAt: occurredAt,
    );

    if (existingInWindow.isNotEmpty) {
      final existing = existingInWindow.first;
      final linked = {...existing.linkedSources, existing.source, source}.toList();
      await _repository.updateLinkedSources(existing.id, linked);
      return DedupResult.merged;
    }

    final exact = await _repository.getByFingerprint(fingerprint);
    if (exact != null) {
      final linked = {...exact.linkedSources, exact.source, source}.toList();
      await _repository.updateLinkedSources(exact.id, linked);
      return DedupResult.merged;
    }

    // Auto-captured money movements are never added silently — every one is
    // held for the user to approve or reject in the Inbox. Confidence is still
    // recorded so the review card can show how sure the parser was.
    final transaction = Transaction(
      id: '${messageTime.millisecondsSinceEpoch}_${source.storageKey}',
      amount: parsed.amount,
      type: parsed.type,
      merchant: parsed.merchant,
      category: parsed.category,
      occurredAt: occurredAt,
      source: source,
      status: TransactionStatus.pendingReview,
      rawText: rawText,
      confidence: parsed.confidence,
      fingerprint: fingerprint,
    );

    await _repository.save(transaction);
    return DedupResult.created;
  }
}
