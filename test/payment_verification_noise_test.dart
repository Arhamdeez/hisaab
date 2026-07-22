import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/features/parser/transaction_parser.dart';
import 'package:spend_tracker/models/transaction.dart';

void main() {
  final parser = TransactionParser();

  test('rejects Google Wallet verify / tap-to-confirm prompt', () {
    expect(
      parser.parse(
        'Verify online payment 🔐 — Tap to confirm USD 3 payment to OnlyFans.',
        source: TransactionSource.notification,
        notificationTitle: 'Original message',
        packageName: 'com.google.android.apps.walletnfcrel',
      ),
      isNull,
    );
  });

  test('rejects 3DS approve payment prompt with amount', () {
    expect(
      parser.parse(
        'Approve this payment of PKR 1,500.00 at DARAZ. Tap to authenticate.',
        source: TransactionSource.notification,
        packageName: 'com.ubluk.dc',
      ),
      isNull,
    );
  });

  test('still parses completed Google Wallet payment', () {
    final result = parser.parse(
      'PKR 500.00 with EP Digital Card Google Wallet ••8421',
      source: TransactionSource.notification,
      notificationTitle: 'STARBUCKS',
      packageName: 'com.google.android.apps.walletnfcrel',
    );
    expect(result, isNotNull);
    expect(result!.amount, 500);
    expect(result.isFailed, isFalse);
  });
}
