import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Transactions, MonthlySummaries, ParserRules, SyncMetadata])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedParserRules();
        },
      );

  Future<void> _seedParserRules() async {
    final rules = [
      ParserRulesCompanion.insert(
        name: 'HDFC Debit',
        pattern:
            r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)\s+(?:debited|spent|paid)',
        sourceHint: const Value('sms'),
      ),
      ParserRulesCompanion.insert(
        name: 'UPI Payment',
        pattern: r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?).*?(?:to|at|for)\s+([A-Za-z0-9 &.-]+)',
        sourceHint: const Value('notification'),
      ),
      ParserRulesCompanion.insert(
        name: 'Credit Received',
        pattern:
            r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)\s+(?:credited|received|deposited)',
        sourceHint: const Value('sms'),
      ),
      ParserRulesCompanion.insert(
        name: 'GPay Notification',
        pattern:
            r'(?:paid|sent)\s+(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)\s+(?:to|for)\s+([A-Za-z0-9 &.-]+)',
        sourceHint: const Value('notification'),
      ),
      ParserRulesCompanion.insert(
        name: 'Paytm Alert',
        pattern:
            r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)\s+(?:spent|paid|debited)',
        sourceHint: const Value('gmail'),
      ),
      ParserRulesCompanion.insert(
        name: 'Amazon Order',
        pattern:
            r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?).*?(?:Amazon|amzn)',
        sourceHint: const Value('gmail'),
      ),
      ParserRulesCompanion.insert(
        name: 'Swiggy/Zomato',
        pattern:
            r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?).*?(?:Swiggy|Zomato|swiggy|zomato)',
        sourceHint: const Value('notification'),
      ),
      ParserRulesCompanion.insert(
        name: 'Generic Debit',
        pattern: r'(?:debited|spent|paid|withdrawn).*?(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)',
        sourceHint: const Value(null),
      ),
      ParserRulesCompanion.insert(
        name: 'Generic Credit',
        pattern: r'(?:credited|received|deposited).*?(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)',
        sourceHint: const Value(null),
      ),
      ParserRulesCompanion.insert(
        name: 'Account Reference',
        pattern: r'A/c\s*\*+\s*(\d{4})',
        sourceHint: const Value('sms'),
      ),
    ];

    await batch((b) => b.insertAll(parserRules, rules));
  }

  Future<List<Transaction>> getAllTransactions() =>
      select(transactions).get();

  Future<List<Transaction>> getTransactionsByStatus(String status) =>
      (select(transactions)..where((t) => t.status.equals(status))).get();

  Future<Transaction?> getByFingerprint(String fingerprint) =>
      (select(transactions)..where((t) => t.fingerprint.equals(fingerprint)))
          .getSingleOrNull();

  Future<Transaction?> getTransactionById(String id) =>
      (select(transactions)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<List<Transaction>> getTransactionsInWindow({
    required String fingerprint,
    required DateTime from,
    required DateTime to,
  }) {
    return (select(transactions)
          ..where(
            (t) =>
                t.fingerprint.equals(fingerprint) &
                t.occurredAt.isBetweenValues(from, to),
          ))
        .get();
  }

  Future<List<Transaction>> getLatestTransactions({int limit = 50}) {
    return (select(transactions)
          ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
          ..limit(limit))
        .get();
  }

  Future<List<Transaction>> getTransactionsByAmountTypeOnDay({
    required double amount,
    required String type,
    required DateTime day,
  }) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return (select(transactions)
          ..where(
            (t) =>
                t.amount.equals(amount) &
                t.type.equals(type) &
                t.occurredAt.isBetweenValues(start, end),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]))
        .get();
  }

  Future<void> upsertTransaction(TransactionsCompanion row) =>
      into(transactions).insertOnConflictUpdate(row);

  Future<void> updateTransactionStatus(String id, String status) async {
    await (update(transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(status: Value(status)),
    );
  }

  /// Applies a review decision in one write: status plus optional merchant and
  /// category overrides (used by the quick-reply notification action).
  /// Returns how many rows were updated (0 if already reviewed).
  Future<int> updateTransactionReviewIfPending(
    String id, {
    required String status,
    String? merchant,
    String? category,
  }) {
    return (update(transactions)
          ..where(
            (t) =>
                t.id.equals(id) &
                t.status.equals('pendingReview'),
          ))
        .write(
      TransactionsCompanion(
        status: Value(status),
        merchant: merchant == null ? const Value.absent() : Value(merchant),
        category: category == null ? const Value.absent() : Value(category),
      ),
    );
  }

  Future<void> updateLinkedSources(String id, String linkedSources) async {
    await (update(transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(linkedSources: Value(linkedSources)),
    );
  }

  Future<void> updateTransactionMerchant(String id, String merchant) async {
    await (update(transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(merchant: Value(merchant)),
    );
  }

  Future<void> updateTransactionCategory(String id, String categoryId) async {
    await (update(transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(category: Value(categoryId)),
    );
  }

  Future<int> reassignTransactionCategory(String fromId, String toId) {
    return (update(transactions)..where((t) => t.category.equals(fromId))).write(
      TransactionsCompanion(category: Value(toId)),
    );
  }

  Future<List<ParserRule>> getEnabledParserRules() =>
      (select(parserRules)..where((r) => r.enabled.equals(true))).get();

  Future<String?> getSyncValue(String key) async {
    final row = await (select(syncMetadata)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setSyncValue(String key, String value) =>
      into(syncMetadata).insertOnConflictUpdate(
        SyncMetadataCompanion(key: Value(key), value: Value(value)),
      );

  Future<void> upsertMonthlySummary(MonthlySummariesCompanion row) =>
      into(monthlySummaries).insertOnConflictUpdate(row);

  Future<int> deleteTransactionsWithIdPrefix(String prefix) =>
      (delete(transactions)..where((t) => t.id.like('$prefix%'))).go();

  Future<MonthlySummary?> getMonthlySummary(String yearMonth) =>
      (select(monthlySummaries)..where((m) => m.yearMonth.equals(yearMonth)))
          .getSingleOrNull();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'spend_tracker.sqlite'));
    return NativeDatabase(
      file,
      setup: (db) {
        // WAL allows a concurrent reader + writer, and a busy timeout makes the
        // background-isolate (notification quick-reply) write wait for a lock
        // instead of failing when the app is also open.
        db.execute('PRAGMA journal_mode = WAL;');
        db.execute('PRAGMA busy_timeout = 3000;');
      },
    );
  });
}
