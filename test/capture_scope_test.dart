import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/features/ingest/monitored_packages.dart';
import 'package:spend_tracker/features/parser/transaction_parser.dart';
import 'package:spend_tracker/models/transaction.dart';

void main() {
  final parser = TransactionParser();

  group('capture scope — finance apps only', () {
    test('blocks WhatsApp even when text looks like a payment', () {
      expect(MonitoredPackages.isExcluded('com.whatsapp'), isTrue);
      expect(
        parser.parse(
          'You sent Rs. 500.00 to Ali Khan via wallet',
          source: TransactionSource.notification,
          packageName: 'com.whatsapp',
        ),
        isNull,
      );
    });

    test('blocks Telegram payment-like chat notifications', () {
      expect(MonitoredPackages.isExcluded('org.telegram.messenger'), isTrue);
      expect(
        parser.parse(
          'PKR 1,200 paid to Ali Khan',
          source: TransactionSource.notification,
          packageName: 'org.telegram.messenger',
        ),
        isNull,
      );
    });

    test('blocks unknown shopping apps with payment wording', () {
      expect(
        parser.parse(
          'You paid Rs. 999 at checkout',
          source: TransactionSource.notification,
          packageName: 'com.some.random.shop',
        ),
        isNull,
      );
    });

    test('still accepts Easypaisa wallet notifications', () {
      final result = parser.parse(
        'Dear MUHAMMAD ARHAM BABAR, An amount of Rs. 1.0 has been successfully sent to '
        'ALI IBRAHIM MUHAMMAD in ********1541 via Raast Payment from your Easypaisa account '
        '*******0101 on 2026-06-26 at 05:53:41. Trx ID: 51829532776.',
        source: TransactionSource.notification,
        packageName: 'pk.com.telenor.phoenix',
        notificationTitle: 'easypaisa',
      );
      expect(result, isNotNull);
      expect(result!.amount, 1.0);
    });

    test('still accepts wallet SMS without a package name', () {
      final result = parser.parse(
        'Dear MUHAMMAD ARHAM BABAR, an amount of Rs. 1 has been successfully sent to '
        'ALI IBRAHIM MUHAMMAD of IBAN No: ****1541 on 2026-06-26 at 05:52:16. '
        'TID:715814224891 via RAAST',
        source: TransactionSource.sms,
      );
      expect(result, isNotNull);
      expect(result!.amount, 1.0);
    });

    test('still accepts Gmail bank alerts', () {
      final result = parser.parse(
        'Money Transfer of Rs. 1000.0 to ALI IBRAHIM was successful. Trx ID: 12345',
        source: TransactionSource.notification,
        packageName: 'com.google.android.gm',
      );
      expect(result, isNotNull);
      expect(result!.amount, 1000.0);
    });
  });
}
