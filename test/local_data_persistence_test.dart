import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spend_tracker/core/data/local_data_persistence.dart';
import 'package:spend_tracker/core/database/app_database.dart' hide Transaction;
import 'package:spend_tracker/core/repositories/transaction_repository.dart';
import 'package:spend_tracker/models/transaction.dart';

Transaction _txn(String id) {
  return Transaction(
    id: id,
    amount: 500,
    type: TransactionType.debit,
    merchant: 'Test Shop',
    categoryId: SpendingCategory.other.storageKey,
    occurredAt: DateTime(2026, 6, 1),
    source: TransactionSource.notification,
    status: TransactionStatus.confirmed,
    fingerprint: 'fp_$id',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalDataPersistence', () {
    late AppDatabase db;
    late TransactionRepository repository;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = TransactionRepository(db);
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() async {
      await db.close();
    });

    test('recoverReturningUser skips onboarding when transactions exist', () async {
      final prefs = await SharedPreferences.getInstance();
      await repository.save(_txn('real_1'));

      final recovered = await LocalDataPersistence.recoverReturningUser(
        repository: repository,
        prefs: prefs,
      );

      expect(recovered, isTrue);
      expect(
        prefs.getBool(LocalDataPersistence.onboardingCompleteKey),
        isTrue,
      );
    });

    test('recoverReturningUser does nothing for fresh installs', () async {
      final prefs = await SharedPreferences.getInstance();

      final recovered = await LocalDataPersistence.recoverReturningUser(
        repository: repository,
        prefs: prefs,
      );

      expect(recovered, isFalse);
      expect(prefs.getBool(LocalDataPersistence.onboardingCompleteKey), isNull);
    });

    test('cleanupLegacyDevDataOnly removes seed rows once', () async {
      final prefs = await SharedPreferences.getInstance();
      await repository.save(_txn('seed_demo'));
      await repository.save(_txn('live_1'));

      await LocalDataPersistence.cleanupLegacyDevDataOnce(
        repository: repository,
        prefs: prefs,
      );
      await LocalDataPersistence.cleanupLegacyDevDataOnce(
        repository: repository,
        prefs: prefs,
      );

      final remaining = await repository.getAll();
      expect(remaining.map((t) => t.id), ['live_1']);
    });
  });
}
