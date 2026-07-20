import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/core/database/app_database.dart';
import 'package:spend_tracker/core/repositories/transaction_repository.dart';
import 'package:spend_tracker/core/utils/cash_flow.dart';
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
    String accountHolderName = 'MUHAMMAD ARHAM BABAR',
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
      accountHolderName: accountHolderName,
    );
  }

  test('auto-confirms easypaisa rs 1 raast payment from notification shade', () async {
    const text =
        'Dear MUHAMMAD ARHAM BABAR, An amount of Rs. 1.0 has been successfully sent to '
        'ALI IBRAHIM MUHAMMAD in *******1541 via Raast Payment from your Easypaisa account '
        '*******0101 on 2026-06-20 at 04:37:57. Trx ID: 51560858320.';
    final when = DateTime(2026, 6, 20, 4, 37);

    final outcome = await ingest(text: text, messageTime: when);

    expect(outcome.result, DedupResult.created);
    expect(outcome.transaction?.amount, 1.0);
    expect((await repository.getAll()).length, 1);
  });

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

  test('back-to-back opposite legs auto-confirm without review', () async {
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
    expect(second.transaction?.status, TransactionStatus.confirmed);

    final all = await repository.getAll();
    expect(all.where((t) => t.status == TransactionStatus.pendingReview).length, 0);
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

  test('merges NayaPay app got-money with gmail You-got alert', () async {
    final notifyTime = DateTime(2026, 7, 17, 11, 0);
    final emailTime = notifyTime.add(const Duration(minutes: 8));

    final appParsed = parser.parse(
      'ADEEL AHMAD sent you Rs. 300. Go ahead, check that balance.',
      source: TransactionSource.notification,
      packageName: 'com.nayapay.app',
      notificationTitle: "You've got money 🤑",
      fallbackTime: notifyTime,
    );
    expect(appParsed, isNotNull);
    expect(appParsed!.type, TransactionType.credit);
    expect(appParsed.merchant, 'ADEEL AHMAD');

    final first = await deduplicator.processIncoming(
      parsed: appParsed,
      source: TransactionSource.notification,
      rawText: 'ADEEL AHMAD sent you Rs. 300. Go ahead, check that balance.',
      messageTime: notifyTime,
    );
    expect(first.result, DedupResult.created);

    final emailParsed = parser.parse(
      '2 new messages — NayaPay You got Rs. 300 from ADEEL AHMAD 🎉',
      source: TransactionSource.gmail,
      packageName: 'com.google.android.gm',
      notificationTitle: '2 new messages',
      fallbackTime: emailTime,
    );
    expect(emailParsed, isNotNull);
    expect(emailParsed!.merchant, 'ADEEL AHMAD');

    final second = await deduplicator.processIncoming(
      parsed: emailParsed,
      source: TransactionSource.gmail,
      rawText: '2 new messages — NayaPay You got Rs. 300 from ADEEL AHMAD 🎉',
      messageTime: emailTime,
    );

    expect(second.result, DedupResult.merged);
    expect((await repository.getAll()).length, 1);
    expect((await repository.getAll()).single.amount, 300.0);
    expect((await repository.getAll()).single.merchant, 'ADEEL AHMAD');
  });

  test('merges easypaisa push after wallet app when merchants differ', () async {
    final notifyTime = DateTime(2026, 6, 20, 4, 37);
    final emailTime = notifyTime.add(const Duration(minutes: 12));

    final first = await ingest(
      text:
          'Dear MUHAMMAD ARHAM BABAR, An amount of Rs. 1000.0 has been successfully sent to '
          'ZAIN UI ABIDEEN in *******0917 via Raast Payment from your Easypaisa account '
          '*******0101 on 2026-06-20 at 04:37:57. Trx ID: 51560858320.',
      messageTime: notifyTime,
      source: TransactionSource.notification,
    );
    expect(first.result, DedupResult.created);

    final second = await deduplicator.processIncoming(
      parsed: parser.parse(
        'Money Transfer of Rs. 1000.0 to ZAIN UI ABIDEEN was successful',
        source: TransactionSource.gmail,
        fallbackTime: emailTime,
      )!,
      source: TransactionSource.gmail,
      rawText: 'Money Transfer of Rs. 1000.0 to ZAIN UI ABIDEEN was successful',
      messageTime: emailTime,
    );

    expect(second.result, DedupResult.merged);
    expect((await repository.getAll()).length, 1);
  });

  test('keeps two distinct payments with different trx ids', () async {
    final first = await ingest(
      text:
          'Rs. 1.0 sent to MISBAH BABAR with easypaisa account 03101464378. '
          'Fee: Rs. 0.0. Trx ID 51830190523.',
      messageTime: DateTime(2026, 6, 26, 6, 24),
      source: TransactionSource.notification,
    );
    expect(first.result, DedupResult.created);

    // Same person, same amount, same day, same channel — but a NEW payment with
    // a different Trx ID. It must register as its own transaction.
    final second = await ingest(
      text:
          'Rs. 1.0 sent to MISBAH BABAR with easypaisa account 03101464378. '
          'Fee: Rs. 0.0. Trx ID 51830777111.',
      messageTime: DateTime(2026, 6, 26, 6, 40),
      source: TransactionSource.notification,
    );

    expect(second.result, DedupResult.created);
    expect((await repository.getAll()).length, 2);
  });

  test('merges same payment across channels sharing a trx id', () async {
    final first = await ingest(
      text:
          'Rs. 1.0 sent to MISBAH BABAR with easypaisa account 03101464378. '
          'Fee: Rs. 0.0. Trx ID 51830190523.',
      messageTime: DateTime(2026, 6, 26, 6, 24),
      source: TransactionSource.notification,
    );
    expect(first.result, DedupResult.created);

    // The bank SMS for the very same payment carries the same Trx ID.
    final second = await ingest(
      text:
          'Dear Customer, an amount of Rs.1 has been debited. Trx ID: 51830190523.',
      messageTime: DateTime(2026, 6, 26, 6, 25),
      source: TransactionSource.sms,
    );

    expect(second.result, DedupResult.merged);
    expect((await repository.getAll()).length, 1);
  });

  test('flags easypaisa self-received transfer for review', () async {
    const text =
        'Dear MUHAMMAD ARHAM BABAR, You have received Rs.1 in your Easypaisa account '
        '***********0101 from MUHAMMAD ARHAM BABAR PK**UNILPKKARTG****7613 via Raast Payment '
        'on 22-06-2026 at 04:18:31. Trx ID: 51649571871';
    final when = DateTime(2026, 6, 22, 4, 18);

    final outcome = await ingest(text: text, messageTime: when);

    expect(outcome.result, DedupResult.created);
    expect(outcome.transaction?.status, TransactionStatus.pendingReview);
    expect(outcome.transaction?.isPending, isTrue);
  });

  test('flags easypaisa raast self-transfer from nayapay for review', () async {
    const text =
        'Dear MUHAMMAD ARHAM BABAR, You have received Rs.1500 in your Easypaisa account '
        '***********0101 from MUHAMMAD ARHAM BABAR PK**NAYAPKKA**0101 via Raast Payment '
        'on 09-07-2026 at 02:20:07. Trx ID: 52438501193';
    final when = DateTime(2026, 7, 9, 2, 20);

    final outcome = await ingest(text: text, messageTime: when);

    expect(outcome.result, DedupResult.created);
    expect(outcome.transaction?.status, TransactionStatus.pendingReview);
    expect(outcome.transaction?.amount, 1500);
    expect(outcome.transaction?.type, TransactionType.credit);
  });

  test('auto-confirms easypaisa payment to another person', () async {
    const text =
        'Dear MUHAMMAD ARHAM BABAR, An amount of Rs. 1000.0 has been successfully sent to '
        'ZAIN UI ABIDEEN in *******0917 via Raast Payment from your Easypaisa account '
        '*******0101 on 2026-06-20 at 04:37:57. Trx ID: 51560858320.';
    final when = DateTime(2026, 6, 20, 4, 37);

    final outcome = await ingest(
      text: text,
      messageTime: when,
      accountHolderName: 'MUHAMMAD ARHAM BABAR',
    );

    expect(outcome.result, DedupResult.created);
    expect(outcome.transaction?.status, TransactionStatus.confirmed);
  });

  test('flags transfer to saved account holder name for inbox review', () async {
    const text =
        'PKR 8,000.00 paid to Muhammad Arham Babar via Raast on 20-JUN-2026';
    final when = DateTime(2026, 6, 20, 10, 0);

    final outcome = await ingest(
      text: text,
      messageTime: when,
      accountHolderName: 'Muhammad Arham Babar',
    );

    expect(outcome.transaction?.status, TransactionStatus.pendingReview);
  });

  test('flags self-transfer when saved name differs only by case', () async {
    const text =
        'PKR 8,000.00 paid to MUHAMMAD ARHAM BABAR via Raast on 20-JUN-2026';
    final when = DateTime(2026, 6, 20, 10, 0);

    final outcome = await ingest(
      text: text,
      messageTime: when,
      accountHolderName: 'muhammad arham babar',
    );

    expect(outcome.transaction?.status, TransactionStatus.pendingReview);
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

  test('does not create a second row when the same alert is ingested again', () async {
    const text =
        'Dear MUHAMMAD ARHAM BABAR, An amount of Rs. 1.0 has been successfully sent to '
        'ALI IBRAHIM MUHAMMAD in *******1541 via Raast Payment from your Easypaisa account '
        '*******0101 on 2026-06-26 at 05:53:41. Trx ID: 51829532776.';
    final when = DateTime(2026, 6, 26, 5, 53);

    final first = await ingest(text: text, messageTime: when);
    expect(first.result, DedupResult.created);

    final second = await ingest(
      text: text,
      messageTime: when.add(const Duration(hours: 6)),
    );
    expect(second.result, DedupResult.merged);
    expect((await repository.getAll()).length, 1);
  });

  test('upgrades generic merchant when cross-source alert has the real name', () async {
    final when = DateTime(2026, 6, 26, 6, 24);
    final first = await deduplicator.processIncoming(
      parsed: ParsedTransaction(
        amount: 1,
        type: TransactionType.debit,
        merchant: 'Easypaisa',
        category: SpendingCategory.other,
        confidence: 0.9,
        occurredAt: when,
      ),
      source: TransactionSource.notification,
      rawText: 'Money sent via Easypaisa',
      messageTime: when,
    );
    expect(first.result, DedupResult.created);

    final second = await ingest(
      text:
          'Dear MUHAMMAD ARHAM BABAR, an amount of Rs. 1 has been successfully sent to '
          'ALI IBRAHIM MUHAMMAD of IBAN No: ****1541 on 2026-06-26 at 06:24:16. '
          'TID:715814224891 via RAAST',
      messageTime: when.add(const Duration(seconds: 45)),
      source: TransactionSource.sms,
    );

    expect(second.result, DedupResult.merged);
    expect((await repository.getAll()).length, 1);
    expect(
      (await repository.getAll()).single.merchant,
      'ALI IBRAHIM MUHAMMAD',
    );
  });

  test('stores failed online transaction with failed status (not in spend)', () async {
    const text =
        'Online transaction failed — Transaction of Rs. 376.80 at '
        'SHOPIFY* 560398773 SINGAPORE SG failed because of insufficient '
        'funds in your wallet.';
    final when = DateTime(2026, 7, 10, 3, 13);

    final parsed = parser.parse(
      text,
      source: TransactionSource.notification,
      fallbackTime: when,
      packageName: 'com.ubluk.dc',
    );
    expect(parsed, isNotNull);
    expect(parsed!.isFailed, isTrue);
    expect(parsed.amount, 376.80);

    final outcome = await deduplicator.processIncoming(
      parsed: parsed,
      source: TransactionSource.notification,
      rawText: text,
      messageTime: when,
    );

    expect(outcome.result, DedupResult.created);
    expect(outcome.transaction?.status, TransactionStatus.failed);
    expect(outcome.transaction?.amount, 376.80);

    final all = await repository.getAll();
    expect(all.single.status, TransactionStatus.failed);

    // Failed rows must not affect cash-in / cash-out totals.
    final flow = CashFlowMetrics.fromTransactions(all);
    expect(flow.cashOut, 0);
    expect(flow.cashIn, 0);
  });
}
