import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/features/parser/transaction_parser.dart';
import 'package:spend_tracker/models/transaction.dart';

void main() {
  final parser = TransactionParser();

  test('names UBL-style ATM debit SMS as ATM, not the For info helpline', () {
    final result = parser.parse(
      'MUHAMMAD ARHAM BABAR A/C *7613 is debited with PKR 15,000 on 08/09/26 '
      'at 18:25 from ATM. For info: 111825888.',
      source: TransactionSource.sms,
    );

    expect(result, isNotNull);
    expect(result!.amount, 15000);
    expect(result.type, TransactionType.debit);
    expect(result.merchant, 'ATM');
    expect(result.merchant, isNot(contains('111825888')));
    expect(result.accountRef, '7613');
  });

  test('names via-ATM withdrawal as ATM', () {
    final result = parser.parse(
      'A/C *7613 is debited with PKR 2,000 on 08/09/26 at 09:10 via ATM.',
      source: TransactionSource.sms,
    );

    expect(result, isNotNull);
    expect(result!.merchant, 'ATM');
    expect(result.type, TransactionType.debit);
  });

  test('keeps a named ATM location instead of a generic ATM label', () {
    final result = parser.parse(
      'Rs. 2,000.00 ATM CASH WITHDRAWAL at HBL ATM GULBERG in A/C xxx1200 '
      'on 13-Jul-2026 at 18:40',
      source: TransactionSource.notification,
      notificationTitle: 'Transaction Alert',
      packageName: 'com.hbl.android.hblmobilebanking',
    );

    expect(result, isNotNull);
    expect(result!.merchant.toUpperCase(), contains('GULBERG'));
    expect(result.merchant.toUpperCase(), isNot(equals('ATM')));
  });
}
