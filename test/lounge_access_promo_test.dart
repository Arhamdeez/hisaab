import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/features/parser/transaction_parser.dart';
import 'package:spend_tracker/models/transaction.dart';

void main() {
  final parser = TransactionParser();

  test('rejects airport lounge access promo priced at Rs. 1', () {
    expect(
      parser.parse(
        'Premium lounge access in Rs. 1 — Debit card se airport lounge access '
        'sirf Rs. 1 mein!',
        source: TransactionSource.notification,
        notificationTitle: 'Premium lounge access in Rs. 1',
      ),
      isNull,
    );
  });

  test('rejects lounge promo from bank/wallet app package', () {
    expect(
      parser.parse(
        'Premium lounge access in Rs. 1 — Debit card se airport lounge access '
        'sirf Rs. 1 mein!',
        source: TransactionSource.notification,
        notificationTitle: 'Premium lounge access in Rs. 1',
        packageName: 'com.meezanbank.mobile',
      ),
      isNull,
    );
  });

  test('rejects lounge promo when body is only amount-style title', () {
    expect(
      parser.parse(
        'Debit card se airport lounge access sirf Rs. 1 mein!',
        source: TransactionSource.notification,
        notificationTitle: 'Premium lounge access in Rs. 1',
        packageName: 'pk.com.habibbank.mobilebanking',
      ),
      isNull,
    );
  });
}
