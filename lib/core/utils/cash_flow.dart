import '../../models/transaction.dart';

/// Confirmed money movement totals for cash-flow UI.
class CashFlowMetrics {
  const CashFlowMetrics({
    required this.cashIn,
    required this.cashOut,
  });

  final double cashIn;
  final double cashOut;

  double get net => cashIn - cashOut;

  /// How much of received money was spent — 1.0 = break-even, >1 = overspent.
  double get cashOutOfCashIn => cashIn > 0 ? cashOut / cashIn : 0;

  /// 0–1 portion of the larger side used for proportional bars (in vs out).
  double get cashInBarShare {
    final peak = cashIn > cashOut ? cashIn : cashOut;
    if (peak <= 0) return 0.5;
    return cashIn / peak;
  }

  double get cashOutBarShare {
    final peak = cashIn > cashOut ? cashIn : cashOut;
    if (peak <= 0) return 0.5;
    return cashOut / peak;
  }

  static CashFlowMetrics fromTransactions(Iterable<Transaction> txs) {
    var cashIn = 0.0;
    var cashOut = 0.0;
    for (final t in txs) {
      if (t.status != TransactionStatus.confirmed) continue;
      switch (t.type) {
        case TransactionType.credit:
          cashIn += t.amount;
        case TransactionType.debit:
          cashOut += t.amount;
      }
    }
    return CashFlowMetrics(cashIn: cashIn, cashOut: cashOut);
  }
}
