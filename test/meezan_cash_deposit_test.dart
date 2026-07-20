import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/features/parser/transaction_parser.dart';
import 'package:spend_tracker/models/transaction.dart';

void main() {
  final parser = TransactionParser();

  test('parses Meezan cash deposit LCY notification', () {
    const body =
        'PKR 12,000.00 CASH DEPOSIT-LCY at AHMED PUR EAST BR APE in A/C xxx9931 '
        'on 16-Jul-2026 at 16:16';
    final result = parser.parse(
      body,
      source: TransactionSource.notification,
      notificationTitle: 'Meezan Bank Alert',
      packageName: 'com.meezanbank.mobile',
    );

    expect(result, isNotNull);
    expect(result!.amount, 12000);
    expect(result.type, TransactionType.credit);
    expect(result.merchant.toUpperCase(), contains('AHMED PUR EAST'));
    expect(result.accountRef, '9931');
    expect(result.occurredAt, DateTime(2026, 7, 16, 16, 16));
  });

  test('parses Meezan cash withdrawal LCY notification as debit', () {
    final result = parser.parse(
      'PKR 5,000.00 CASH WITHDRAWAL-LCY at DHA PHASE 6 BR in A/C xxx3625 '
      'on 16-Jul-2026 at 11:05',
      source: TransactionSource.notification,
      notificationTitle: 'Meezan Bank Alert',
      packageName: 'com.meezanbank.mobile',
    );

    expect(result, isNotNull);
    expect(result!.amount, 5000);
    expect(result.type, TransactionType.debit);
    expect(result.merchant.toUpperCase(), contains('DHA PHASE'));
  });

  test('parses HBL cash deposit with x-masked account', () {
    final result = parser.parse(
      'PKR 8,500.00 CASH DEPOSIT at MAIN BRANCH in A/C xxx4412 on 15-Jul-2026 at 09:30',
      source: TransactionSource.notification,
      notificationTitle: 'HBL Account Alert',
      packageName: 'com.hbl.android.hblmobilebanking',
    );

    expect(result, isNotNull);
    expect(result!.amount, 8500);
    expect(result.type, TransactionType.credit);
    expect(result.accountRef, '4412');
  });

  test('parses UBL deposit credited wording still works', () {
    final result = parser.parse(
      'PKR 3,000.00 has been deposited in your A/C **7788 on 14-Jul-2026',
      source: TransactionSource.notification,
      notificationTitle: 'UBL Transaction Alert',
      packageName: 'com.ubluk.dc',
    );

    expect(result, isNotNull);
    expect(result!.amount, 3000);
    expect(result.type, TransactionType.credit);
  });

  test('parses ATM cash withdrawal without asterisk account mask', () {
    final result = parser.parse(
      'Rs. 2,000.00 ATM CASH WITHDRAWAL at HBL ATM GULBERG in A/C xxx1200 '
      'on 13-Jul-2026 at 18:40',
      source: TransactionSource.notification,
      notificationTitle: 'Transaction Alert',
      packageName: 'com.hbl.android.hblmobilebanking',
    );

    expect(result, isNotNull);
    expect(result!.amount, 2000);
    expect(result.type, TransactionType.debit);
  });
}
