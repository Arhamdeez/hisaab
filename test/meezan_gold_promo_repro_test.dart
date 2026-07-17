import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/features/parser/transaction_parser.dart';
import 'package:spend_tracker/models/transaction.dart';

void main() {
  final parser = TransactionParser();
  const promo =
      'Apne Meezan Visa Gold Card se PKR 50,000 international spend karein '
      'aur Honda CD 70 aur Yadea M3 eBike jeetne ka mauqa hasil karein';

  test('rejects Meezan Gold spend-and-win promo with -Rs threshold', () {
    expect(
      parser.parse(
        '$promo\n-Rs 50,000.00',
        source: TransactionSource.notification,
        packageName: 'com.meezanbank.mobile',
      ),
      isNull,
    );
  });

  test('rejects when promo is title and body is only -Rs amount', () {
    expect(
      parser.parse(
        '-Rs 50,000.00',
        source: TransactionSource.notification,
        notificationTitle: promo,
        packageName: 'com.meezanbank.mobile',
      ),
      isNull,
    );
  });

  test('does not treat Meezan Bank + bare amount as a person-name debit', () {
    expect(
      parser.parse(
        '-Rs 50,000.00',
        source: TransactionSource.notification,
        notificationTitle: 'Meezan Bank',
        packageName: 'com.meezanbank.mobile',
      ),
      isNull,
    );
  });

  test('does not treat Visa Gold Card title + bare amount as a debit', () {
    expect(
      parser.parse(
        'Rs 50,000.00',
        source: TransactionSource.notification,
        notificationTitle: 'Meezan Visa Gold Card',
        packageName: 'com.meezanbank.mobile',
      ),
      isNull,
    );
  });

  test('still accepts person-name title with amount-only body', () {
    final result = parser.parse(
      '2,000.00',
      source: TransactionSource.notification,
      notificationTitle: 'Ali Khan',
      packageName: 'com.techlogix.mobilinkcustomer',
    );
    expect(result, isNotNull);
    expect(result!.amount, 2000.0);
    expect(result.merchant, 'Ali Khan');
  });
}
