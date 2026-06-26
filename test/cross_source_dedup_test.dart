import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/features/dedup/cross_source_dedup.dart';
import 'package:spend_tracker/models/transaction.dart';

Transaction _txn({
  required String id,
  required TransactionSource source,
  required TransactionType type,
  double amount = 1500,
  required DateTime occurredAt,
  String merchant = 'Ali Khan',
}) {
  return Transaction(
    id: id,
    amount: amount,
    type: type,
    merchant: merchant,
    categoryId: SpendingCategory.other.storageKey,
    occurredAt: occurredAt,
    source: source,
    status: TransactionStatus.confirmed,
    rawText: 'raw',
    confidence: 0.9,
    fingerprint: 'fp_$id',
  );
}

void main() {
  test('merges notification with gmail when email shows wallet name only', () {
    final notifyTime = DateTime(2026, 6, 16, 14, 0);
    final emailTime = notifyTime.add(const Duration(minutes: 20));
    final existing = _txn(
      id: '${notifyTime.millisecondsSinceEpoch}_notification',
      source: TransactionSource.notification,
      type: TransactionType.debit,
      occurredAt: DateTime(2026, 6, 16),
      merchant: 'ZAIN UI ABIDEEN',
    );

    final match = CrossSourceDedup.findMatch(
      candidates: [existing],
      incomingSource: TransactionSource.gmail,
      amount: 1500,
      type: TransactionType.debit,
      messageTime: emailTime,
      occurredAt: DateTime(2026, 6, 16),
      merchant: 'Easypaisa',
    );

    expect(match?.id, existing.id);
  });

  test('merges notification with later gmail for same payment', () {
    final notifyTime = DateTime(2026, 6, 16, 14, 0);
    final emailTime = notifyTime.add(const Duration(minutes: 20));
    final existing = _txn(
      id: '${notifyTime.millisecondsSinceEpoch}_notification',
      source: TransactionSource.notification,
      type: TransactionType.debit,
      occurredAt: DateTime(2026, 6, 16),
      merchant: 'Ali Khan',
    );

    final match = CrossSourceDedup.findMatch(
      candidates: [existing],
      incomingSource: TransactionSource.gmail,
      amount: 1500,
      type: TransactionType.debit,
      messageTime: emailTime,
      occurredAt: DateTime(2026, 6, 16),
      merchant: 'Ali Khan Store',
    );

    expect(match?.id, existing.id);
  });

  test('merges same payment across channels even with unrelated labels', () {
    // App push shows the counterparty name; the bank SMS shows a masked
    // account number. Same exact transaction minute -> same payment.
    final occurred = DateTime(2026, 6, 26, 6, 24);
    final existing = _txn(
      id: '${occurred.millisecondsSinceEpoch}_notification',
      source: TransactionSource.notification,
      type: TransactionType.debit,
      amount: 1,
      occurredAt: occurred,
      merchant: 'Mohammad Haris Imran',
    );

    final match = CrossSourceDedup.findMatch(
      candidates: [existing],
      incomingSource: TransactionSource.sms,
      amount: 1,
      type: TransactionType.debit,
      messageTime: occurred.add(const Duration(seconds: 40)),
      occurredAt: occurred.add(const Duration(minutes: 1)),
      merchant: '8558',
    );

    expect(match?.id, existing.id);
  });

  test('merges notification with gmail for same payment minute', () {
    final occurred = DateTime(2026, 6, 26, 6, 24);
    final existing = _txn(
      id: '${occurred.millisecondsSinceEpoch}_notification',
      source: TransactionSource.notification,
      type: TransactionType.debit,
      amount: 1,
      occurredAt: occurred,
      merchant: 'Mohammad Haris Imran',
    );

    final match = CrossSourceDedup.findMatch(
      candidates: [existing],
      incomingSource: TransactionSource.gmail,
      amount: 1,
      type: TransactionType.debit,
      messageTime: occurred.add(const Duration(minutes: 5)),
      occurredAt: occurred,
      merchant: 'NayaPay',
    );

    expect(match?.id, existing.id);
  });

  test('does not merge different merchants far apart in time', () {
    final existing = _txn(
      id: '1_notification',
      source: TransactionSource.notification,
      type: TransactionType.debit,
      occurredAt: DateTime(2026, 6, 16, 8),
      merchant: 'Swiggy',
    );

    final match = CrossSourceDedup.findMatch(
      candidates: [existing],
      incomingSource: TransactionSource.gmail,
      amount: 1500,
      type: TransactionType.debit,
      messageTime: DateTime(2026, 6, 16, 20),
      occurredAt: DateTime(2026, 6, 16, 20),
      merchant: 'Careem',
    );

    expect(match, isNull);
  });

  test('does not merge same source twice', () {
    final existing = _txn(
      id: '1_notification',
      source: TransactionSource.notification,
      type: TransactionType.debit,
      occurredAt: DateTime(2026, 6, 16),
    );

    final match = CrossSourceDedup.findMatch(
      candidates: [existing],
      incomingSource: TransactionSource.notification,
      amount: 1500,
      type: TransactionType.debit,
      messageTime: DateTime(2026, 6, 16, 14, 5),
      occurredAt: DateTime(2026, 6, 16),
      merchant: 'Ali Khan',
    );

    expect(match, isNull);
  });

  test('does not merge distinct payments same amount different minutes', () {
    final first = DateTime(2026, 6, 26, 6, 24);
    final existing = _txn(
      id: '${first.millisecondsSinceEpoch}_notification',
      source: TransactionSource.notification,
      type: TransactionType.debit,
      amount: 1,
      occurredAt: first,
      merchant: 'Ali Khan',
    );

    // Second, genuinely separate payment to a different person an hour later,
    // reported only by email -> must not collapse into the first.
    final match = CrossSourceDedup.findMatch(
      candidates: [existing],
      incomingSource: TransactionSource.gmail,
      amount: 1,
      type: TransactionType.debit,
      messageTime: first.add(const Duration(hours: 1)),
      occurredAt: first.add(const Duration(hours: 1)),
      merchant: 'Fareed Motors',
    );

    expect(match, isNull);
  });
}
