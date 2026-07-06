import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/features/dedup/rescan_dedup.dart';
import 'package:spend_tracker/models/transaction.dart';

Transaction _txn({
  required String id,
  required String rawText,
  TransactionSource source = TransactionSource.notification,
  double amount = 1,
}) {
  return Transaction(
    id: id,
    amount: amount,
    type: TransactionType.debit,
    merchant: 'Ali Khan',
    categoryId: SpendingCategory.other.storageKey,
    occurredAt: DateTime(2026, 6, 26, 6, 24),
    source: source,
    status: TransactionStatus.confirmed,
    rawText: rawText,
    confidence: 0.9,
    fingerprint: 'fp_$id',
  );
}

void main() {
  const alert =
      'Dear MUHAMMAD ARHAM BABAR, An amount of Rs. 1.0 has been successfully sent to '
      'ALI IBRAHIM MUHAMMAD in *******1541 via Raast Payment from your Easypaisa account '
      '*******0101 on 2026-06-26 at 05:53:41. Trx ID: 51829532776.';

  test('matches identical alert text on rescan', () {
    final existing = _txn(id: '1', rawText: alert);
    final match = RescanDedup.findMatch(
      candidates: [existing],
      amount: 1,
      type: TransactionType.debit,
      rawText: '  $alert  ',
      referenceId: '51829532776',
    );
    expect(match?.id, existing.id);
  });

  test('matches same trx id across different wording', () {
    final existing = _txn(id: '1', rawText: alert);
    final match = RescanDedup.findMatch(
      candidates: [existing],
      amount: 1,
      type: TransactionType.debit,
      rawText: 'Trx ID: 51829532776 debited Rs. 1',
      referenceId: '51829532776',
    );
    expect(match?.id, existing.id);
  });

  test('does not match different trx ids with same amount', () {
    final existing = _txn(id: '1', rawText: alert);
    final match = RescanDedup.findMatch(
      candidates: [existing],
      amount: 1,
      type: TransactionType.debit,
      rawText:
          'Rs. 1.0 sent to MISBAH BABAR. Fee: Rs. 0.0. Trx ID 51830777111.',
      referenceId: '51830777111',
    );
    expect(match, isNull);
  });
}
