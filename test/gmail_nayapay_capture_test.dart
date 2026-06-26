import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/features/parser/transaction_parser.dart';
import 'package:spend_tracker/models/transaction.dart';

void main() {
  final parser = TransactionParser();

  test('parses gmail nayapay notification with multiline body', () {
    const text =
        'NayaPay — You sent Rs. 1 to Mohammad Haris Imran 💸\n'
        'Mohammad Haris Imran\n'
        'Meezan — 1154\n'
        '26 Jun 2026, 06:11 AM — Rs. 1\n'
        'AMO';
    final result = parser.parse(
      text,
      source: TransactionSource.gmail,
      packageName: 'com.google.android.gm',
      notificationTitle: 'NayaPay',
    );
    expect(result, isNotNull, reason: text);
    expect(result!.amount, 1.0);
    expect(result.merchant, contains('Mohammad Haris Imran'));
  });

  test('parses nayapay app notification', () {
    const text =
        "Off it goes 💸 — Rs. 1 sent to Mohammad Haris Imran. Your wallet's seen better days.";
    final result = parser.parse(
      text,
      source: TransactionSource.notification,
      packageName: 'com.nayapay.app',
      notificationTitle: 'Off it goes 💸',
    );
    expect(result, isNotNull);
    expect(result!.amount, 1.0);
    expect(result.merchant, 'Mohammad Haris Imran');
  });
}
