import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/features/parser/transaction_parser.dart';
import 'package:spend_tracker/models/transaction.dart';

void main() {
  final parser = TransactionParser();

  test('parses easypaisa raast sent notification', () {
    final result = parser.parse(
      'Dear MUHAMMAD ARHAM BABAR, An amount of Rs. 1000.0 has been successfully sent to ZAIN UI ABIDEEN in *******0917 via Raast Payment from your Easypaisa account *******0101 on 2026-06-20 at 04:37:57. Trx ID: 51560858320.',
      source: TransactionSource.notification,
      packageName: 'pk.com.telenor.phoenix',
      notificationTitle: 'easypaisa',
    );
    expect(result, isNotNull);
    expect(result!.amount, 1000);
    expect(result.type, TransactionType.debit);
    expect(result.merchant, 'ZAIN UI ABIDEEN');
  });

  test('parses easypaisa rs 1 raast with iso date and nanosecond time', () {
    final result = parser.parse(
      'Dear MUHAMMAD ARHAM BABAR, An amount of Rs. 1.0 has been successfully sent to '
      'ALI IBRAHIM MUHAMMAD in ********1541 via Raast Payment from your Easypaisa account '
      '*******0101 on 2026-06-26 at 05:42:12.037682068. Trx ID: 51829415254.',
      source: TransactionSource.notification,
      packageName: 'pk.com.telenor.phoenix',
      notificationTitle: 'easypaisa',
      fallbackTime: DateTime(2026, 6, 26, 5, 42),
    );
    expect(result, isNotNull);
    expect(result!.amount, 1.0);
    expect(result.type, TransactionType.debit);
    expect(result.merchant, 'ALI IBRAHIM MUHAMMAD');
    expect(result.occurredAt, DateTime(2026, 6, 26, 5, 42));
  });

  test('parses gmail raast e-statement notification', () {
    final result = parser.parse(
      'Money Transfer via Raast Payment — Transaction Successful — Hi MUHAMMAD ARHAM BABAR, Money Transfer of Rs. 1000.0 on 20-Jun-2026 to Raast ID/IBAN was successful',
      source: TransactionSource.notification,
      packageName: 'com.google.android.gm',
      notificationTitle: 'e.statement',
    );
    expect(result, isNotNull);
    expect(result!.amount, 1000);
    expect(result.type, TransactionType.debit);
  });

  test('uses Account Title as merchant from EasyPaisa Raast e-statement email', () {
    const body = '''
Money Transfer via Raast Payment Transaction Successful
Hi MUHAMMAD ARHAM BABAR,
Money Transfer of Rs. 350.0 on 18-Jul-2026 to Raast ID/IBAN was successful
TRANSACTION DETAILS
Transaction Type Raast Payment
Transaction ID 52889864323
Date & Time 18-Jul-2026 16:55:02
Raast ID/IBAN *******9232
Account Title MUHAMMAD ARSHAD
Sender Name MUHAMMAD ARHAM BABAR
Sender Number 03244200101
AMOUNT DETAILS
Transfer amount Rs. 350.0
Fee Rs. 0.00
Total Rs. 350.0
''';
    final result = parser.parse(
      body,
      source: TransactionSource.notification,
      packageName: 'com.google.android.gm',
      notificationTitle: 'e.statement',
    );

    expect(result, isNotNull);
    expect(result!.amount, 350);
    expect(result.type, TransactionType.debit);
    expect(result.merchant, 'MUHAMMAD ARSHAD');
    expect(result.receiverName, 'MUHAMMAD ARSHAD');
    expect(result.merchant, isNot(contains('Account Title')));
    expect(result.merchant, isNot(contains('Sender Name')));
  });

  test('does not use flattened e-statement field dump as merchant', () {
    const body =
        'Date & Time 18-Jul-2026 17:49:22 Raast ID/ IBAN *******0101 '
        'Account Title MUHAMMAD ARHAM BABAR Sender Name MUHAMMAD ARHAM BABAR '
        'Sender Number 03244200101 AMOUNT DETAILS Transfer amount Rs. 1000.0 '
        'Fee Rs. 0.00 Total Rs. 1000.0 Money Transfer of Rs. 1000.0 on '
        '18-Jul-2026 to Raast ID/IBAN was successful';
    final result = parser.parse(
      body,
      source: TransactionSource.notification,
      packageName: 'com.google.android.gm',
      notificationTitle: 'e.statement',
    );

    expect(result, isNotNull);
    expect(result!.amount, 1000);
    expect(result.type, TransactionType.debit);
    expect(result.merchant, 'MUHAMMAD ARHAM BABAR');
    expect(result.merchant.length, lessThan(40));
    expect(result.merchant, isNot(contains('Date & Time')));
    expect(result.merchant, isNot(contains('AMOUNT DETAILS')));
  });
}
