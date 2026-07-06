import '../../core/repositories/transaction_repository.dart';
import '../../models/transaction.dart';
import '../parser/transaction_parser.dart';
import 'burst_dedup.dart';
import 'rescan_dedup.dart';
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
    String? accountHolderName,
  }) async {
    final occurredAt = parsed.occurredAt ?? messageTime;
    final referenceId = parsed.referenceId;
    final fingerprint = TransactionParser.buildFingerprint(
      amount: parsed.amount,
      occurredAt: occurredAt,
      merchant: parsed.merchant,
      accountRef: parsed.accountRef,
      referenceId: referenceId,
    );

    final existingInWindow = await _repository.getInDedupWindow(
      fingerprint: fingerprint,
      occurredAt: occurredAt,
    );

    if (existingInWindow.isNotEmpty) {
      return _mergeExisting(
        existing: existingInWindow.first,
        source: source,
        merchant: parsed.merchant,
      );
    }

    final exact = await _repository.getByFingerprint(fingerprint);
    if (exact != null) {
      return _mergeExisting(
        existing: exact,
        source: source,
        merchant: parsed.merchant,
      );
    }

    final recentCandidates = await _repository.getLatestTransactions(limit: 80);
    final rescanDuplicate = RescanDedup.findMatch(
      candidates: recentCandidates,
      amount: parsed.amount,
      type: parsed.type,
      rawText: rawText,
      referenceId: referenceId,
    );
    if (rescanDuplicate != null) {
      return _mergeExisting(
        existing: rescanDuplicate,
        source: source,
        merchant: parsed.merchant,
      );
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
      referenceId: referenceId,
    );
    if (crossSource != null) {
      return _mergeExisting(
        existing: crossSource,
        source: source,
        merchant: parsed.merchant,
      );
    }

    final paymentAlert = await _repository.findPaymentAlertDuplicate(
      amount: parsed.amount,
      type: parsed.type,
      occurredAt: occurredAt,
      messageTime: messageTime,
      merchant: parsed.merchant,
      referenceId: referenceId,
    );
    if (paymentAlert != null) {
      return _mergeExisting(
        existing: paymentAlert,
        source: source,
        merchant: parsed.merchant,
      );
    }

    final burstDuplicate = await _repository.findBurstDuplicate(
      amount: parsed.amount,
      type: parsed.type,
      source: source,
      messageTime: messageTime,
      merchant: parsed.merchant,
      referenceId: referenceId,
    );
    if (burstDuplicate != null) {
      return _mergeExisting(
        existing: burstDuplicate,
        source: source,
        merchant: parsed.merchant,
      );
    }

    final recent = await _repository.getLatestTransactions();
    var needsReview = ReviewPolicy.requiresReview(
      parsed: parsed,
      rawText: rawText,
      messageTime: messageTime,
      recent: recent,
      accountHolderName: accountHolderName,
    );

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

  Future<IngestOutcome> _mergeExisting({
    required Transaction existing,
    required TransactionSource source,
    required String merchant,
  }) async {
    final linked = {...existing.linkedSources, existing.source, source}.toList();
    await _repository.updateLinkedSources(existing.id, linked);
    final better = BurstDedup.pickBetterMerchant(existing.merchant, merchant);
    if (better != existing.merchant) {
      await _repository.updateMerchant(existing.id, better);
    }
    return const IngestOutcome(DedupResult.merged);
  }
}
