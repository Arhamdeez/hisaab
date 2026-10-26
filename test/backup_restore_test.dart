import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spend_tracker/core/data/local_data_persistence.dart';
import 'package:spend_tracker/core/database/app_database.dart' hide Transaction;
import 'package:spend_tracker/core/repositories/transaction_repository.dart';
import 'package:spend_tracker/features/backup/backup_preferences.dart';
import 'package:spend_tracker/features/backup/backup_service.dart';
import 'package:spend_tracker/models/transaction.dart';
import 'package:spend_tracker/providers/app_preferences.dart';
import 'package:spend_tracker/providers/category_catalog.dart';

Transaction _txn(String id, {required String merchant}) {
  return Transaction(
    id: id,
    amount: 500,
    type: TransactionType.debit,
    merchant: merchant,
    categoryId: SpendingCategory.other.storageKey,
    occurredAt: DateTime(2026, 6, 1),
    source: TransactionSource.notification,
    status: TransactionStatus.confirmed,
    fingerprint: 'fp_$id',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('hisaab_backup_test_');
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('snapshot restores past transactions and preferences', () async {
    final sourceDb = AppDatabase.forFile(File('${root.path}/source.sqlite'));
    final sourceRepo = TransactionRepository(sourceDb);
    addTearDown(sourceDb.close);

    await sourceRepo.save(_txn('past_1', merchant: 'Cafe'));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(AppPreferences.monthlyIncomeKey, 80000);
    await prefs.setBool('show_income', true);
    await prefs.setString(
      CategoryCatalog.storageKey,
      '[{"id":"custom_1","name":"Tea","icon":0,"color":1}]',
    );

    final snapshot = await BackupService(sourceRepo).createSnapshotFile(
      destination: Directory('${root.path}/snaps'),
    );

    expect(
      await sourceDb.getSyncValue(BackupPreferences.storageKey),
      isNull,
    );
    expect(snapshot.path, endsWith('.sqlite'));

    final freshDb = AppDatabase.forFile(File('${root.path}/fresh.sqlite'));
    final freshRepo = TransactionRepository(freshDb);
    addTearDown(() => freshRepo.database.close());
    await freshRepo.save(_txn('current_1', merchant: 'Now'));
    await prefs.setDouble(AppPreferences.monthlyIncomeKey, 1);
    await prefs.remove('show_income');

    final restored = await BackupService(freshRepo).restoreFromFile(
      snapshot.path,
      confirm: (count) async {
        expect(count, 1);
        return true;
      },
      scratchDirectory: Directory('${root.path}/scratch'),
    );

    expect(restored.isSuccess, isTrue);
    expect(restored.count, 1);
    final rows = await freshRepo.getAll();
    expect(rows.map((row) => row.id), ['past_1']);
    expect(rows.single.merchant, 'Cafe');

    final after = await SharedPreferences.getInstance();
    expect(after.getDouble(AppPreferences.monthlyIncomeKey), 80000);
    expect(after.getBool('show_income'), isTrue);
    expect(after.getBool(LocalDataPersistence.onboardingCompleteKey), isTrue);
    expect(after.getString(CategoryCatalog.storageKey), contains('Tea'));
  });

  test('a text file is rejected and current transactions stay', () async {
    final db = AppDatabase.forFile(File('${root.path}/live.sqlite'));
    final repo = TransactionRepository(db);
    addTearDown(() => repo.database.close());
    await repo.save(_txn('keep', merchant: 'Shop'));

    final text = File('${root.path}/notes.txt');
    await text.writeAsString('HISAAB — Transactions Backup');

    final result = await BackupService(repo).restoreFromFile(
      text.path,
      confirm: (_) async => fail('should not ask to confirm an invalid file'),
      scratchDirectory: Directory('${root.path}/scratch'),
    );

    expect(result.isFailure, isTrue);
    expect((await repo.getAll()).single.id, 'keep');
  });

  test('a database that was not exported is rejected', () async {
    final liveDb = AppDatabase.forFile(File('${root.path}/live.sqlite'));
    final repo = TransactionRepository(liveDb);
    addTearDown(() => repo.database.close());
    await repo.save(_txn('keep', merchant: 'Shop'));

    final other = File('${root.path}/other.sqlite');
    final otherDb = AppDatabase.forFile(other);
    await otherDb.customStatement('SELECT 1');
    await otherDb.close();

    final result = await BackupService(repo).restoreFromFile(
      other.path,
      confirm: (_) async => fail('should not confirm a file without a backup marker'),
      scratchDirectory: Directory('${root.path}/scratch'),
    );

    expect(result.isFailure, isTrue);
    expect((await repo.getAll()).single.id, 'keep');
  });

  test('cancelling restore leaves the current transactions in place', () async {
    final sourceDb = AppDatabase.forFile(File('${root.path}/source.sqlite'));
    final sourceRepo = TransactionRepository(sourceDb);
    addTearDown(sourceDb.close);
    await sourceRepo.save(_txn('past_1', merchant: 'Cafe'));
    final snapshot = await BackupService(sourceRepo).createSnapshotFile(
      destination: Directory('${root.path}/snaps'),
    );

    final freshDb = AppDatabase.forFile(File('${root.path}/fresh.sqlite'));
    final freshRepo = TransactionRepository(freshDb);
    addTearDown(() => freshRepo.database.close());
    await freshRepo.save(_txn('current_1', merchant: 'Now'));

    final result = await BackupService(freshRepo).restoreFromFile(
      snapshot.path,
      confirm: (_) async => false,
      scratchDirectory: Directory('${root.path}/scratch'),
    );

    expect(result.isCancelled, isTrue);
    expect((await freshRepo.getAll()).single.id, 'current_1');
  });
}
