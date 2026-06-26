import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/features/dedup/payment_alert_dedup.dart';
import 'package:spend_tracker/models/transaction.dart';

Transaction _txn({
  required String id,
  required TransactionSource source,
  required DateTime occurredAt,
  String merchant = 'ZAIN UI ABIDEEN',
}) {
  return Transaction(
    id: id,
    amount: 1000,
    type: TransactionType.debit,
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
  test('merges wallet push with gmail shade alert for same payment', () {
    final notifyTime = DateTime(2026, 6, 20, 4, 37);
    final gmailTime = notifyTime.add(const Duration(minutes: 8));
    final existing = _txn(
      id: '${notifyTime.millisecondsSinceEpoch}_notification',
      source: TransactionSource.notification,
      occurredAt: DateTime(2026, 6, 20),
      merchant: 'ZAIN UI ABIDEEN',
    );

    final match = PaymentAlertDedup.findMatch(
      candidates: [existing],
      amount: 1000,
      type: TransactionType.debit,
      messageTime: gmailTime,
      merchant: 'Money Transfer',
    );

    expect(match?.id, existing.id);
  });

  test('does not merge unrelated same-amount payments hours apart', () {
    final existing = _txn(
      id: '1_notification',
      source: TransactionSource.notification,
      occurredAt: DateTime(2026, 6, 16, 8),
      merchant: 'Swiggy',
    );

    final match = PaymentAlertDedup.findMatch(
      candidates: [existing],
      amount: 1000,
      type: TransactionType.debit,
      messageTime: DateTime(2026, 6, 16, 14),
      merchant: 'Careem',
    );

    expect(match, isNull);
  });
}
