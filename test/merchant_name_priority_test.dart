import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/features/parser/transaction_parser.dart';
import 'package:spend_tracker/models/transaction.dart';

void main() {
  final parser = TransactionParser();

  group('never uses alert headings as merchant names', () {
    test('JazzCash Raast Incoming Payment uses sender from body', () {
      final result = parser.parse(
        'Raast Incoming Payment — Rs 100 received from MUHAMMAD USMAN ADNAN AC '
        '***************107033625 in your JazzCash Mobile Account:03244200101 '
        'via Raast. TID: 717461292210',
        source: TransactionSource.notification,
        packageName: 'com.techlogix.mobilinkcustomer',
        notificationTitle: 'Raast Incoming Payment',
      );
      expect(result, isNotNull);
      expect(result!.amount, 100);
      expect(result.type, TransactionType.credit);
      expect(result.merchant.toUpperCase(), contains('MUHAMMAD USMAN'));
      expect(result.merchant.toLowerCase(), isNot(contains('raast')));
      expect(result.merchant.toLowerCase(), isNot(contains('incoming')));
    });

    test('Meezan Bank Alert uses payee from sent to', () {
      final result = parser.parse(
        'Meezan Bank Alert — PKR 100.00 sent to M.ARHAM PK40JCMAxx010 as RAAST '
        'payment from your AC# xxx3625 of KH E JINNAH BR LHR on 13 — Jul — 2026 '
        'at 13:08 TID:935776.',
        source: TransactionSource.notification,
        packageName: 'com.meezanbank.mobile',
        notificationTitle: 'Meezan Bank Alert',
      );
      expect(result, isNotNull);
      expect(result!.merchant, 'M.ARHAM');
    });

    test('UBL Transaction Alert uses body counterparty', () {
      final result = parser.parse(
        'PKR 2,500.00 has been sent to ALI KHAN via IBFT from A/c **3625. '
        'TID: 998877.',
        source: TransactionSource.notification,
        packageName: 'com.ubluk.dc',
        notificationTitle: 'UBL Transaction Alert',
      );
      expect(result, isNotNull);
      expect(result!.type, TransactionType.debit);
      expect(result.merchant.toUpperCase(), contains('ALI'));
      expect(result.merchant.toLowerCase(), isNot(contains('ubl')));
      expect(result.merchant.toLowerCase(), isNot(contains('alert')));
    });

    test('HBL Account Alert does not become merchant on credit', () {
      final result = parser.parse(
        'Rs 5,000.00 received from SARA AHMED in your account via Raast. '
        'TID: 112233.',
        source: TransactionSource.notification,
        packageName: 'com.hbl.android.hblmobilebanking',
        notificationTitle: 'HBL Account Alert',
      );
      expect(result, isNotNull);
      expect(result!.type, TransactionType.credit);
      expect(result.merchant.toUpperCase(), contains('SARA'));
      expect(result.merchant.toLowerCase(), isNot(contains('hbl')));
      expect(result.merchant.toLowerCase(), isNot(contains('alert')));
    });

    test('generic Incoming Payment heading is ignored', () {
      final result = parser.parse(
        'Rs 250 received from FATIMA BIBI AC ********1234 via Raast. TID: 55',
        source: TransactionSource.notification,
        packageName: 'com.techlogix.mobilinkcustomer',
        notificationTitle: 'Incoming Payment',
      );
      expect(result, isNotNull);
      expect(result!.merchant.toUpperCase(), contains('FATIMA'));
      expect(result.merchant.toLowerCase(), isNot(contains('incoming')));
    });

    test('login security alerts stay rejected', () {
      expect(
        parser.parse(
          'Login Successful — You have successfully logged in to Meezan bank '
          'Mobile App. Call helpline at +92 21 111 — 331 — 331.',
          source: TransactionSource.notification,
          packageName: 'com.meezanbank.mobile',
          notificationTitle: 'Login Successful',
        ),
        isNull,
      );
    });
  });

  group('person and merchant titles that already work stay intact', () {
    test('JazzCash person-name title with amount-only body', () {
      final result = parser.parse(
        '2,000.00',
        source: TransactionSource.notification,
        packageName: 'com.techlogix.mobilinkcustomer',
        notificationTitle: 'Ahmed Khan',
      );
      expect(result, isNotNull);
      expect(result!.amount, 2000);
      expect(result.merchant, 'Ahmed Khan');
    });

    test('Google Wallet merchant title with PKR tap', () {
      final result = parser.parse(
        'PKR330.00 with EP Digital Card Google Wallet ••8421',
        source: TransactionSource.notification,
        packageName: 'com.google.android.apps.walletnfcrel',
        notificationTitle: 'THE FAST MART',
      );
      expect(result, isNotNull);
      expect(result!.merchant, 'THE FAST MART');
    });

    test('NayaPay sent-to still prefers body name over casual title', () {
      final result = parser.parse(
        "Rs. 190 sent to Inam Ullah. Your wallet's seen better days.",
        source: TransactionSource.notification,
        packageName: 'com.nayapay.app',
        notificationTitle: 'Off it goes 💸',
      );
      expect(result, isNotNull);
      expect(result!.merchant, 'Inam Ullah');
    });
  });
}
