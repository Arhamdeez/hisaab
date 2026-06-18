import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/core/database/app_database.dart';
import 'package:spend_tracker/core/repositories/transaction_repository.dart';
import 'package:spend_tracker/features/dedup/deduplicator.dart';
import 'package:spend_tracker/features/parser/transaction_parser.dart';
import 'package:spend_tracker/models/transaction.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository repository;
  late Deduplicator deduplicator;
  late TransactionParser parser;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = TransactionRepository(db);
    deduplicator = Deduplicator(repository);
    parser = TransactionParser();
  });

  tearDown(() async {
    await db.close();
  });

  Future<IngestOutcome> ingest({
    required String text,
    required DateTime messageTime,
    TransactionSource source = TransactionSource.notification,
  }) async {
    final parsed = parser.parse(
      text,
      source: source,
      fallbackTime: messageTime,
    );
    expect(parsed, isNotNull, reason: text);
    return deduplicator.processIncoming(
      parsed: parsed!,
      source: source,
      rawText: text,
      messageTime: messageTime,
    );
  }

  test('auto-confirms a normal merchant payment', () async {
    final when = DateTime(2026, 6, 16, 14, 30);
    final outcome = await ingest(
      text: 'PKR 1,200 paid to Ali Khan via wallet',
      messageTime: when,
    );

    expect(outcome.result, DedupResult.created);
    expect(outcome.transaction?.status, TransactionStatus.confirmed);
    expect(outcome.transaction?.isPending, isFalse);
  });

  test('flags self-transfer with matching sender and receiver', () async {
    final when = DateTime(2026, 6, 16, 15, 0);
    final outcome = await ingest(
      text: 'PKR 5,000 transferred from Arham Babar to Arham Babar',
      messageTime: when,
    );

    expect(outcome.transaction?.status, TransactionStatus.pendingReview);
    expect(outcome.transaction?.isPending, isTrue);
  });

  test('flags back-to-back opposite legs and upgrades the first leg', () async {
    final firstTime = DateTime(2026, 6, 16, 16, 0);
    final secondTime = firstTime.add(const Duration(seconds: 40));

    final first = await ingest(
      text: 'PKR 10,000 credited to A/c **1234 on 16-JUN-2026',
      messageTime: firstTime,
    );
    expect(first.transaction?.status, TransactionStatus.confirmed);

    final second = await ingest(
      text: 'PKR 10,000 debited from A/c **5678 on 16-JUN-2026',
      messageTime: secondTime,
    );
    expect(second.transaction?.status, TransactionStatus.pendingReview);

    final all = await repository.getAll();
    expect(all.where((t) => t.status == TransactionStatus.pendingReview).length, 2);
  });

  test('does not flag unrelated payments with different amounts', () async {
    final when = DateTime(2026, 6, 16, 17, 0);
    await ingest(
      text: 'PKR 3,000 credited to A/c **1234 on 16-JUN-2026',
      messageTime: when,
    );

    final outcome = await ingest(
      text: 'PKR 1,500 debited from A/c **5678 at SWIGGY on 16-JUN-2026',
      messageTime: when.add(const Duration(seconds: 30)),
    );

    expect(outcome.transaction?.status, TransactionStatus.confirmed);
  });

  test('merges gmail alert after app notification for same payment', () async {
    final notifyTime = DateTime(2026, 6, 16, 18, 0);
    final emailTime = notifyTime.add(const Duration(minutes: 15));

    final first = await ingest(
      text: 'You sent Rs. 2,000.00 to Ali Khan via JazzCash',
      messageTime: notifyTime,
      source: TransactionSource.notification,
    );
    expect(first.result, DedupResult.created);

    final parsed = parser.parse(
      'Transaction Alert: PKR 2,000.00 paid to Ali Khan on 16-JUN-2026',
      source: TransactionSource.gmail,
      fallbackTime: emailTime,
    );
    expect(parsed, isNotNull);

    final second = await deduplicator.processIncoming(
      parsed: parsed!,
      source: TransactionSource.gmail,
      rawText: 'Transaction Alert: PKR 2,000.00 paid to Ali Khan',
      messageTime: emailTime,
    );

    expect(second.result, DedupResult.merged);
    expect((await repository.getAll()).length, 1);
  });

  test('merges repeated wallet alerts within a few seconds', () async {
    final firstTime = DateTime(2026, 6, 16, 19, 0);
    final secondTime = firstTime.add(const Duration(seconds: 8));

    final first = await ingest(
      text: 'You sent Rs. 2,000.00 to Ali Khan via JazzCash',
      messageTime: firstTime,
    );
    expect(first.result, DedupResult.created);

    final second = await ingest(
      text: 'Ali Khan. — Rs. 2,000.00 sent successfully. Trx ID 123',
      messageTime: secondTime,
    );
    expect(second.result, DedupResult.merged);
    expect((await repository.getAll()).length, 1);
    expect((await repository.getAll()).single.merchant, 'Ali Khan');
  });
}
