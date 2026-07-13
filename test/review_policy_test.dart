import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/features/dedup/review_policy.dart';
import 'package:spend_tracker/features/parser/transaction_parser.dart';
import 'package:spend_tracker/models/transaction.dart';

ParsedTransaction _parsed({
  double amount = 5000,
  TransactionType type = TransactionType.debit,
  String? senderName,
  String? receiverName,
  String merchant = 'Test',
}) {
  return ParsedTransaction(
    amount: amount,
    type: type,
    merchant: merchant,
    category: SpendingCategory.other,
    confidence: 0.9,
    senderName: senderName,
    receiverName: receiverName,
  );
}

Transaction _txn({
  required String id,
  required TransactionType type,
  double amount = 5000,
  required DateTime occurredAt,
  TransactionStatus status = TransactionStatus.confirmed,
}) {
  return Transaction(
    id: id,
    amount: amount,
    type: type,
    merchant: 'Test',
    categoryId: SpendingCategory.other.storageKey,
    occurredAt: occurredAt,
    source: TransactionSource.notification,
    status: status,
    rawText: 'raw',
    confidence: 0.9,
    fingerprint: 'fp_$id',
  );
}

void main() {
  test('same sender and receiver names require review', () {
    final parsed = _parsed(
      senderName: 'Arham Babar',
      receiverName: 'Arham Babar',
    );
    expect(
      ReviewPolicy.sameSenderAndReceiver(parsed: parsed, rawText: 'sent to Arham'),
      isTrue,
    );
  });

  test('self-transfer phrase requires review', () {
    final parsed = _parsed();
    expect(
      ReviewPolicy.sameSenderAndReceiver(
        parsed: parsed,
        rawText: 'Transfer to own account completed',
      ),
      isTrue,
    );
  });

  test('different parties do not require review by name alone', () {
    final parsed = _parsed(
      senderName: 'Arham',
      receiverName: 'Ali Khan',
    );
    expect(
      ReviewPolicy.sameSenderAndReceiver(
        parsed: parsed,
        rawText: 'Paid to Ali Khan',
      ),
      isFalse,
    );
  });

  test('credit from account holder own name requires review', () {
    const raw =
        'Dear MUHAMMAD ARHAM BABAR, You have received Rs.1 in your Easypaisa account '
        'from MUHAMMAD ARHAM BABAR PK**UNILPKKARTG via Raast Payment';
    final parsed = _parsed(
      type: TransactionType.credit,
      amount: 1,
      senderName: 'MUHAMMAD ARHAM BABAR',
    );
    expect(ReviewPolicy.extractAccountHolderName(raw), 'MUHAMMAD ARHAM BABAR');
    expect(
      ReviewPolicy.involvesAccountHolder(parsed: parsed, rawText: raw),
      isTrue,
    );
    expect(
      ReviewPolicy.requiresReview(
        parsed: parsed,
        rawText: raw,
        messageTime: DateTime(2026, 6, 22),
        recent: const [],
      ),
      isTrue,
    );
  });

  test('saved account holder name flags self-transfer without Dear greeting', () {
    const raw = 'PKR 8,000 paid to Muhammad Arham Babar via Raast';
    final parsed = _parsed(
      receiverName: 'Muhammad Arham Babar',
      merchant: 'Muhammad Arham Babar',
    );
    expect(
      ReviewPolicy.involvesAccountHolder(
        parsed: parsed,
        rawText: raw,
        accountHolderName: 'Muhammad Arham Babar',
      ),
      isTrue,
    );
    expect(
      ReviewPolicy.requiresReview(
        parsed: parsed,
        rawText: raw,
        messageTime: DateTime(2026, 6, 22),
        recent: const [],
        accountHolderName: 'Muhammad Arham Babar',
      ),
      isTrue,
    );
  });

  test('payment to someone else does not require review by holder name', () {
    const raw =
        'Dear MUHAMMAD ARHAM BABAR, An amount of Rs. 1000 has been sent to ZAIN UI ABIDEEN '
        'via Raast Payment from your Easypaisa account';
    final parsed = _parsed(
      receiverName: 'ZAIN UI ABIDEEN',
    );
    expect(
      ReviewPolicy.involvesAccountHolder(parsed: parsed, rawText: raw),
      isFalse,
    );
    expect(
      ReviewPolicy.requiresReview(
        parsed: parsed,
        rawText: raw,
        messageTime: DateTime(2026, 6, 22),
        recent: const [],
        accountHolderName: 'MUHAMMAD ARHAM BABAR',
      ),
      isFalse,
    );
  });

  test('namesMatch ignores letter case', () {
    expect(
      ReviewPolicy.namesMatch(
        'MUHAMMAD ARHAM BABAR',
        'muhammad arham babar',
      ),
      isTrue,
    );
    expect(
      ReviewPolicy.namesMatch(
        'Muhammad Arham Babar',
        'MUHAMMAD arham BABAR',
      ),
      isTrue,
    );
    expect(
      ReviewPolicy.normalizeName('  Muhammad   Arham Babar  '),
      'muhammad arham babar',
    );
  });

  test('involvesAccountHolder matches saved name regardless of case', () {
    const raw = 'You received Rs.500 from muhammad arham babar via Raast';
    final parsed = _parsed(
      type: TransactionType.credit,
      amount: 500,
      senderName: 'MUHAMMAD ARHAM BABAR',
    );
    expect(
      ReviewPolicy.involvesAccountHolder(
        parsed: parsed,
        rawText: raw,
        accountHolderName: 'muhammad arham babar',
      ),
      isTrue,
    );
    expect(
      ReviewPolicy.involvesAccountHolder(
        parsed: parsed,
        rawText: raw,
        accountHolderName: 'Muhammad Arham Babar',
      ),
      isTrue,
    );
  });

  test('same sender and receiver names require review regardless of case', () {
    final parsed = _parsed(
      senderName: 'MUHAMMAD ARHAM BABAR',
      receiverName: 'muhammad arham babar',
    );
    expect(
      ReviewPolicy.sameSenderAndReceiver(parsed: parsed, rawText: 'transfer'),
      isTrue,
    );
  });

  test('back-to-back opposite legs require review', () {
    final now = DateTime(2026, 6, 16, 12, 0);
    final recent = [
      _txn(
        id: '1',
        type: TransactionType.credit,
        amount: 5000,
        occurredAt: now.subtract(const Duration(seconds: 45)),
      ),
    ];
    final incoming = _parsed(type: TransactionType.debit, amount: 5000);

    expect(
      ReviewPolicy.isBackToBackTransfer(
        incoming: incoming,
        messageTime: now,
        recent: recent,
      ),
      isTrue,
    );
  });

  test('back-to-back uses capture time when occurredAt is date-only', () {
    final now = DateTime(2026, 6, 16, 12, 0);
    final capturedMs =
        now.subtract(const Duration(seconds: 45)).millisecondsSinceEpoch;
    final recent = [
      _txn(
        id: '${capturedMs}_notification',
        type: TransactionType.credit,
        amount: 5000,
        occurredAt: DateTime(2026, 6, 16),
      ),
    ];

    expect(
      ReviewPolicy.isBackToBackTransfer(
        incoming: _parsed(type: TransactionType.debit, amount: 5000),
        messageTime: now,
        recent: recent,
      ),
      isTrue,
    );
  });

  test('back-to-back ignores captures outside the window', () {
    final now = DateTime(2026, 6, 16, 12, 0);
    final recent = [
      _txn(
        id: '${now.subtract(const Duration(minutes: 5)).millisecondsSinceEpoch}_notification',
        type: TransactionType.credit,
        amount: 5000,
        occurredAt: now.subtract(const Duration(minutes: 5)),
      ),
    ];

    expect(
      ReviewPolicy.isBackToBackTransfer(
        incoming: _parsed(type: TransactionType.debit, amount: 5000),
        messageTime: now,
        recent: recent,
      ),
      isFalse,
    );
  });

  test('matchingTransferLeg finds closest opposite transaction', () {
    final now = DateTime(2026, 6, 16, 12, 0);
    final far = _txn(
      id: 'far',
      type: TransactionType.credit,
      occurredAt: now.subtract(const Duration(minutes: 2, seconds: 30)),
    );
    final near = _txn(
      id: 'near',
      type: TransactionType.credit,
      occurredAt: now.subtract(const Duration(seconds: 20)),
    );

    final leg = ReviewPolicy.matchingTransferLeg(
      incoming: _parsed(type: TransactionType.debit),
      messageTime: now,
      recent: [far, near],
    );

    expect(leg?.id, 'near');
  });
}
