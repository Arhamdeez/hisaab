import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/features/parser/transaction_parser.dart';
import 'package:spend_tracker/models/transaction.dart';

void main() {
  test('parses Meezan Raast debit with dotted payee name not bank alert title', () {
    final parser = TransactionParser();
    const body =
        'Meezan Bank Alert — PKR 100.00 sent to M.ARHAM PK40JCMAxx010 as RAAST payment '
        'from your AC# xxx3625 of KH E JINNAH BR LHR on 13 — Jul — 2026 at 13:08 TID:935776.';
    final result = parser.parse(
      body,
      source: TransactionSource.notification,
      notificationTitle: 'Meezan Bank Alert',
      packageName: 'com.meezanbank.mobile',
    );

    expect(result, isNotNull);
    expect(result!.amount, 100);
    expect(result.type, TransactionType.debit);
    expect(result.merchant, 'M.ARHAM');
    expect(result.receiverName, 'M.ARHAM');
  });

  test('truncateAtSentenceDot keeps dotted initials like M.ARHAM', () {
    expect(
      TransactionParser.normalizeIngestText('M.ARHAM sent Rs 100'),
      'M.ARHAM sent Rs 100',
    );
  });
}
