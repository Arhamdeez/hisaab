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
      merchant: 'Ali Khan Store',
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
      merchant: 'Ali Khan',
    );

    expect(match, isNull);
  });
}
