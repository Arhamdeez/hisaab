import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/features/parser/transaction_parser.dart';
import 'package:spend_tracker/models/transaction.dart';

void main() {
  final parser = TransactionParser();

  group('wallet notification formats from user screenshots', () {
    test('Raqami: You just sent PKR X to NAME', () {
      final result = parser.parse(
        'You just sent PKR 1.00 to ALI IBRAHIM MUHAMMAD',
        source: TransactionSource.notification,
        packageName: 'com.raqamidigital.cbt',
        notificationTitle: 'Transfer Successful! ✅',
      );
      expect(result, isNotNull, reason: 'Raqami transfer alert');
      expect(result!.amount, 1.0);
      expect(result.type, TransactionType.debit);
      expect(result.merchant, 'ALI IBRAHIM MUHAMMAD');
    });

    test('Easypaisa SMS 3737: Raast amount sent', () {
      final result = parser.parse(
        'Dear MUHAMMAD ARHAM BABAR, An amount of Rs. 1.0 has been successfully sent to '
        'ALI IBRAHIM MUHAMMAD in ********1541 via Raast Payment from your Easypaisa account '
        '*******0101 on 2026-06-26 at 05:53:41. Trx ID: 51829532776.',
        source: TransactionSource.sms,
      );
      expect(result, isNotNull, reason: '3737 Easypaisa Raast SMS');
      expect(result!.amount, 1.0);
      expect(result.type, TransactionType.debit);
      expect(result.merchant, 'ALI IBRAHIM MUHAMMAD');
    });

    test('Easypaisa SMS 3737: debit card payment', () {
      final result = parser.parse(
        'Txn ID 51695745211. Debit Card No. ***8421. You have paid Rs. 330.00 at '
        'THE FAST MART LAHORE PK on 2026-06-22. Transaction Fee: Rs. 0.00',
        source: TransactionSource.sms,
      );
      expect(result, isNotNull, reason: '3737 debit card SMS');
      expect(result!.amount, 330);
      expect(result.type, TransactionType.debit);
      expect(result.merchant.toUpperCase(), contains('FAST MART'));
    });

    test('Easypaisa SMS 3737: debit card with comma amount and short-code title', () {
      const text =
          'Txn ID 52438503229. Debit Card No. ***8421. You have paid Rs. 1,100.00 at '
          'BUTT G FAST FOOD (PAYSA) Lahore PK on 2026-07-08. Transaction Fee: Rs. 0.00';
      final withoutTitle = parser.parse(text, source: TransactionSource.sms);
      expect(withoutTitle, isNotNull);
      expect(withoutTitle!.amount, 1100);
      expect(withoutTitle.merchant.toUpperCase(), contains('BUTT G FAST FOOD'));

      final withShortCode = parser.parse(
        text,
        source: TransactionSource.sms,
        notificationTitle: '3737',
      );
      expect(withShortCode, isNotNull);
      expect(withShortCode!.merchant.toUpperCase(), contains('BUTT G FAST FOOD'));
      expect(withShortCode.merchant, isNot('3737'));
    });

    test('Raast SMS 8558: amount sent to NAME of IBAN', () {
      final result = parser.parse(
        'Dear MUHAMMAD ARHAM BABAR, an amount of Rs. 1 has been successfully sent to '
        'ALI IBRAHIM MUHAMMAD of IBAN No: ****1541 on 2026-06-26 at 05:52:16. '
        'TID:715814224891 via RAAST',
        source: TransactionSource.sms,
      );
      expect(result, isNotNull, reason: '8558 Raast SMS');
      expect(result!.amount, 1.0);
      expect(result.type, TransactionType.debit);
      expect(result.merchant, 'ALI IBRAHIM MUHAMMAD');
    });

    test('Easypaisa: amount successfully sent via Raast', () {
      final result = parser.parse(
        'Dear MUHAMMAD ARHAM BABAR, An amount of Rs. 1.0 has been successfully sent to '
        'ALI IBRAHIM MUHAMMAD in ********1541 via Raast Payment from your Easypaisa account '
        '*******0101 on 2026-06-26 at 05:53:41.564641778. Trx ID: 51829532776.',
        source: TransactionSource.notification,
        packageName: 'pk.com.telenor.phoenix',
        notificationTitle: 'easypaisa',
      );
      expect(result, isNotNull, reason: 'Easypaisa Raast');
      expect(result!.amount, 1.0);
      expect(result.type, TransactionType.debit);
      expect(result.merchant, 'ALI IBRAHIM MUHAMMAD');
    });

    test('NayaPay: Rs X sent to NAME with Off it goes title', () {
      final result = parser.parse(
        "Rs. 1 sent to Mohammad Haris Imran. Your wallet's seen better days.",
        source: TransactionSource.notification,
        packageName: 'com.nayapay.app',
        notificationTitle: 'Off it goes 💸',
      );
      expect(result, isNotNull, reason: 'NayaPay casual sent');
      expect(result!.amount, 1.0);
      expect(result.type, TransactionType.debit);
      expect(result.merchant, 'Mohammad Haris Imran');
    });

    test('NayaPay: NAME sent you Rs with got money title', () {
      final result = parser.parse(
        'ADEEL AHMAD sent you Rs. 300. Go ahead, check that balance.',
        source: TransactionSource.notification,
        packageName: 'com.nayapay.app',
        notificationTitle: "You've got money 🤑",
      );
      expect(result, isNotNull, reason: 'NayaPay casual received');
      expect(result!.amount, 300.0);
      expect(result.type, TransactionType.credit);
      expect(result.merchant, 'ADEEL AHMAD');
    });
  });
}
