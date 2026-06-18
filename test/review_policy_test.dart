import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/features/dedup/review_policy.dart';
import 'package:spend_tracker/features/parser/transaction_parser.dart';
import 'package:spend_tracker/models/transaction.dart';

ParsedTransaction _parsed({
  double amount = 5000,
  TransactionType type = TransactionType.debit,
  String? senderName,
  String? receiverName,
}) {
  return ParsedTransaction(
    amount: amount,
    type: type,
    merchant: 'Test',
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
