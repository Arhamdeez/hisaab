import '../../core/repositories/transaction_repository.dart';
import '../../models/transaction.dart';
import '../parser/transaction_parser.dart';
import 'burst_dedup.dart';
import 'review_policy.dart';

enum DedupResult { created, merged, skipped }

/// The outcome of ingesting a single message. When [result] is
/// [DedupResult.created], [transaction] holds the newly stored row so callers
/// can react to it (e.g. post a system notification).
class IngestOutcome {
  const IngestOutcome(this.result, [this.transaction]);

  final DedupResult result;
  final Transaction? transaction;
}

class Deduplicator {
  Deduplicator(this._repository);

  final TransactionRepository _repository;

  Future<IngestOutcome> processIncoming({
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
      return const IngestOutcome(DedupResult.merged);
    }

    final exact = await _repository.getByFingerprint(fingerprint);
    if (exact != null) {
      final linked = {...exact.linkedSources, exact.source, source}.toList();
      await _repository.updateLinkedSources(exact.id, linked);
      return const IngestOutcome(DedupResult.merged);
    }

    // Same payment often arrives as an app notification and an email — merge
    // instead of creating a second row when amount/type/day align.
    final crossSource = await _repository.findCrossSourceDuplicate(
      amount: parsed.amount,
      type: parsed.type,
      occurredAt: occurredAt,
      messageTime: messageTime,
      incomingSource: source,
      merchant: parsed.merchant,
    );
    if (crossSource != null) {
      final linked = {
        ...crossSource.linkedSources,
        crossSource.source,
        source,
      }.toList();
      await _repository.updateLinkedSources(crossSource.id, linked);
      return const IngestOutcome(DedupResult.merged);
    }

    final burstDuplicate = await _repository.findBurstDuplicate(
      amount: parsed.amount,
      type: parsed.type,
      source: source,
      messageTime: messageTime,
      merchant: parsed.merchant,
    );
    if (burstDuplicate != null) {
      final betterMerchant = BurstDedup.pickBetterMerchant(
        burstDuplicate.merchant,
        parsed.merchant,
      );
      if (betterMerchant != burstDuplicate.merchant) {
        await _repository.updateMerchant(burstDuplicate.id, betterMerchant);
      }
      return const IngestOutcome(DedupResult.merged);
    }

    final recent = await _repository.getLatestTransactions();
    var needsReview = ReviewPolicy.requiresReview(
      parsed: parsed,
      rawText: rawText,
      messageTime: messageTime,
      recent: recent,
    );
    if (parsed.confidence < TransactionParser.confidenceThreshold) {
      needsReview = true;
    }

    if (needsReview) {
      final leg = ReviewPolicy.matchingTransferLeg(
        incoming: parsed,
        messageTime: messageTime,
        recent: recent,
      );
      if (leg != null && leg.status == TransactionStatus.confirmed) {
        await _repository.updateStatus(leg.id, TransactionStatus.pendingReview);
      }
    }

    final transaction = Transaction(
      id: '${messageTime.millisecondsSinceEpoch}_${source.storageKey}',
      amount: parsed.amount,
      type: parsed.type,
      merchant: parsed.merchant,
      categoryId: parsed.category.storageKey,
      occurredAt: occurredAt,
      source: source,
      status: needsReview
          ? TransactionStatus.pendingReview
          : TransactionStatus.confirmed,
      rawText: rawText,
      confidence: parsed.confidence,
      fingerprint: fingerprint,
    );

    await _repository.save(transaction);
    return IngestOutcome(DedupResult.created, transaction);
  }
}
