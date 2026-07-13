import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/core/utils/cash_flow.dart';
import 'package:spend_tracker/models/transaction.dart';

Transaction _txn({
  required TransactionType type,
  required double amount,
  TransactionStatus status = TransactionStatus.confirmed,
}) {
  return Transaction(
    id: '${type.name}-$amount',
    amount: amount,
    type: type,
    status: status,
    merchant: 'Test',
    categoryId: SpendingCategory.other.storageKey,
    source: TransactionSource.sms,
    occurredAt: DateTime(2026, 7, 1),
    rawText: 'test',
    fingerprint: 'fp-${type.name}-$amount',
  );
}

void main() {
  group('CashFlowMetrics', () {
    test('cash in sums confirmed credits only', () {
      final flow = CashFlowMetrics.fromTransactions([
        _txn(type: TransactionType.credit, amount: 5000),
        _txn(type: TransactionType.credit, amount: 2000),
        _txn(type: TransactionType.debit, amount: 1500),
        _txn(
          type: TransactionType.credit,
          amount: 999,
          status: TransactionStatus.failed,
        ),
        _txn(
          type: TransactionType.credit,
          amount: 888,
          status: TransactionStatus.pendingReview,
        ),
      ]);

      expect(flow.cashIn, 7000);
      expect(flow.cashOut, 1500);
      expect(flow.net, 5500);
    });

    test('cash out relative to cash in', () {
      const flow = CashFlowMetrics(cashIn: 10000, cashOut: 7500);

      expect(flow.cashOutOfCashIn, 0.75);
      expect(flow.cashInBarShare, 1);
      expect(flow.cashOutBarShare, 0.75);
    });

    test('bars scale to the larger side', () {
      const flow = CashFlowMetrics(cashIn: 3000, cashOut: 9000);

      expect(flow.cashInBarShare, closeTo(1 / 3, 0.0001));
      expect(flow.cashOutBarShare, 1);
    });
  });
}
