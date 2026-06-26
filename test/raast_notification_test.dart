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
}
