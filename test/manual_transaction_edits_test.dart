import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/core/database/app_database.dart' hide Transaction;
import 'package:spend_tracker/core/repositories/transaction_repository.dart';
import 'package:spend_tracker/core/utils/formatters.dart';
import 'package:spend_tracker/features/dedup/deduplicator.dart';
import 'package:spend_tracker/providers/transaction_provider.dart';
import 'package:spend_tracker/models/transaction.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository repository;
  late TransactionProvider provider;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = TransactionRepository(db);
    provider = TransactionProvider(
      repository: repository,
      deduplicator: Deduplicator(repository),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('addManualTransaction stores the chosen date', () async {
    final when = DateTime(2026, 3, 15, 10, 30, 0);
    await provider.addManualTransaction(
      amount: 250,
      merchant: 'Cafe',
      categoryId: SpendingCategory.other.storageKey,
      type: TransactionType.debit,
      occurredAt: when,
    );

    final saved = (await repository.getAll()).single;
    expect(saved.occurredAt, when);
    expect(saved.amount, 250);
    expect(saved.merchant, 'Cafe');
    expect(saved.source, TransactionSource.manual);
  });

  test('updateAmount persists a new amount and fingerprint', () async {
    await provider.addManualTransaction(
      amount: 500,
      merchant: 'Store',
      categoryId: SpendingCategory.other.storageKey,
      type: TransactionType.debit,
      occurredAt: DateTime(2026, 4, 1, 9),
    );
    final original = (await repository.getAll()).single;
    final originalFingerprint = original.fingerprint;

    await provider.updateTransactionAmount(original.id, 750);

    final saved = await repository.getById(original.id);
    expect(saved, isNotNull);
    expect(saved!.amount, 750);
    expect(saved.fingerprint, isNot(originalFingerprint));
    expect(saved.merchant, 'Store');
  });

  test('formatManualEntryDate labels today and yesterday', () {
    final now = DateTime.now();
    expect(formatManualEntryDate(now), 'Today');
    expect(
      formatManualEntryDate(now.subtract(const Duration(days: 1))),
      'Yesterday',
    );
  });
}
