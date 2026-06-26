import 'package:drift/drift.dart';

import '../database/app_database.dart' as db;
import '../../features/parser/transaction_parser.dart';
import '../../models/transaction.dart' as domain;
import '../../features/dedup/cross_source_dedup.dart';
import '../../features/dedup/burst_dedup.dart';
import '../../features/dedup/payment_alert_dedup.dart';

class TransactionRepository {
  TransactionRepository(this._db);

  final db.AppDatabase _db;

  Future<List<domain.Transaction>> getAll() async {
    final rows = await _db.getAllTransactions();
    return rows.map(_mapRow).toList();
  }

  Future<List<domain.Transaction>> getConfirmed() async {
    final rows =
        await _db.getTransactionsByStatus(domain.TransactionStatus.confirmed.storageKey);
    return rows.map(_mapRow).toList();
  }

  Future<domain.Transaction?> getByFingerprint(String fingerprint) async {
    final row = await _db.getByFingerprint(fingerprint);
    return row == null ? null : _mapRow(row);
  }

  Future<List<domain.Transaction>> getInDedupWindow({
    required String fingerprint,
    required DateTime occurredAt,
    Duration window = const Duration(minutes: 15),
  }) async {
    final rows = await _db.getTransactionsInWindow(
      fingerprint: fingerprint,
      from: occurredAt.subtract(window),
      to: occurredAt.add(window),
    );
    return rows.map(_mapRow).toList();
  }

  Future<List<domain.Transaction>> getLatestTransactions({int limit = 50}) async {
    final rows = await _db.getLatestTransactions(limit: limit);
    return rows.map(_mapRow).toList();
  }

  Future<domain.Transaction?> findCrossSourceDuplicate({
    required double amount,
    required domain.TransactionType type,
    required DateTime occurredAt,
    required DateTime messageTime,
    required domain.TransactionSource incomingSource,
    required String merchant,
  }) async {
    final candidates = await _sameDayAmountCandidates(
      amount: amount,
      type: type,
      occurredAt: occurredAt,
      messageTime: messageTime,
    );
    return CrossSourceDedup.findMatch(
      candidates: candidates,
      incomingSource: incomingSource,
      amount: amount,
      type: type,
      messageTime: messageTime,
      merchant: merchant,
    );
  }

  /// Wallet push + Gmail shade alert for the same payment (often same source).
  Future<domain.Transaction?> findPaymentAlertDuplicate({
    required double amount,
    required domain.TransactionType type,
    required DateTime occurredAt,
    required DateTime messageTime,
    required String merchant,
  }) async {
    final candidates = await _sameDayAmountCandidates(
      amount: amount,
      type: type,
      occurredAt: occurredAt,
      messageTime: messageTime,
    );
    return PaymentAlertDedup.findMatch(
      candidates: candidates,
      amount: amount,
      type: type,
      messageTime: messageTime,
      merchant: merchant,
    );
  }

  Future<List<domain.Transaction>> _sameDayAmountCandidates({
    required double amount,
    required domain.TransactionType type,
    required DateTime occurredAt,
    required DateTime messageTime,
  }) async {
    final days = {
      DateTime(occurredAt.year, occurredAt.month, occurredAt.day),
      DateTime(messageTime.year, messageTime.month, messageTime.day),
    };
    final seen = <String>{};
    final candidates = <domain.Transaction>[];
    for (final day in days) {
      final rows = await _db.getTransactionsByAmountTypeOnDay(
        amount: amount,
        type: type.storageKey,
        day: day,
      );
      for (final row in rows) {
        if (seen.add(row.id)) {
          candidates.add(_mapRow(row));
        }
      }
    }
    return candidates;
  }

  Future<domain.Transaction?> findBurstDuplicate({
    required double amount,
    required domain.TransactionType type,
    required domain.TransactionSource source,
    required DateTime messageTime,
    required String merchant,
  }) async {
    final recent = await getLatestTransactions(limit: 30);
    for (final existing in recent) {
      if (BurstDedup.matches(
        existing: existing,
        amount: amount,
        type: type,
        source: source,
        messageTime: messageTime,
        merchant: merchant,
      )) {
        return existing;
      }
    }
    return null;
  }

  Future<void> updateMerchant(String id, String merchant) =>
      _db.updateTransactionMerchant(id, merchant);

  Future<void> updateCategory(String id, String categoryId) =>
      _db.updateTransactionCategory(id, categoryId);

  Future<void> save(domain.Transaction transaction) async {
    await _db.upsertTransaction(_toCompanion(transaction));
  }

  Future<void> updateStatus(String id, domain.TransactionStatus status) =>
      _db.updateTransactionStatus(id, status.storageKey);

  Future<domain.Transaction?> getById(String id) async {
    final row = await _db.getTransactionById(id);
    return row == null ? null : _mapRow(row);
  }

  /// Applies a review decision in a single DB write when still pending.
  /// Returns true if a row was updated.
  Future<bool> applyReview(
    String id, {
    required domain.TransactionStatus status,
    String? merchant,
    String? categoryId,
  }) async {
    final trimmed = merchant?.trim();
    final rows = await _db.updateTransactionReviewIfPending(
      id,
      status: status.storageKey,
      merchant: (trimmed != null && trimmed.isNotEmpty) ? trimmed : null,
      category: categoryId,
    );
    return rows > 0;
  }

  Future<int> reassignCategory(String fromId, String toId) =>
      _db.reassignTransactionCategory(fromId, toId);

  Future<void> updateLinkedSources(
    String id,
    List<domain.TransactionSource> sources,
  ) =>
      _db.updateLinkedSources(id, domain.linkedSourcesToJson(sources));

  /// Removes legacy demo rows seeded during development.
  Future<int> deleteLegacySeedData() =>
      _db.deleteTransactionsWithIdPrefix('seed_');

  Future<List<ParserRule>> getParserRules() async {
    final rows = await _db.getEnabledParserRules();
    return rows
        .map(
          (r) => ParserRule(
            id: r.id,
            name: r.name,
            pattern: r.pattern,
            sourceHint: r.sourceHint,
            enabled: r.enabled,
          ),
        )
        .toList();
  }

  Future<void> cacheMonthlySummary({
    required String yearMonth,
    required double totalDebit,
    required double totalCredit,
    required String byCategoryJson,
    required int transactionCount,
  }) {
    return _db.upsertMonthlySummary(
      db.MonthlySummariesCompanion(
        yearMonth: Value(yearMonth),
        totalDebit: Value(totalDebit),
        totalCredit: Value(totalCredit),
        byCategoryJson: Value(byCategoryJson),
        transactionCount: Value(transactionCount),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  domain.Transaction _mapRow(db.Transaction row) {
    return domain.Transaction(
      id: row.id,
      amount: row.amount,
      currency: row.currency,
      type: domain.TransactionTypeX.fromKey(row.type),
      merchant: row.merchant,
      categoryId: row.category,
      occurredAt: row.occurredAt,
      source: domain.TransactionSourceX.fromKey(row.source),
      status: domain.TransactionStatusX.fromKey(row.status),
      rawText: row.rawText,
      confidence: row.confidence,
      fingerprint: row.fingerprint,
      linkedSources: domain.linkedSourcesFromJson(row.linkedSources),
    );
  }

  db.TransactionsCompanion _toCompanion(domain.Transaction t) {
    return db.TransactionsCompanion(
      id: Value(t.id),
      amount: Value(t.amount),
      currency: Value(t.currency),
      type: Value(t.type.storageKey),
      merchant: Value(t.merchant),
      category: Value(t.categoryId),
      occurredAt: Value(t.occurredAt),
      source: Value(t.source.storageKey),
      rawText: Value(t.rawText),
      confidence: Value(t.confidence),
      status: Value(t.status.storageKey),
      fingerprint: Value(t.fingerprint),
      linkedSources: Value(domain.linkedSourcesToJson(t.linkedSources)),
    );
  }
}
