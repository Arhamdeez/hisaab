import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/features/parser/transaction_parser.dart';
import 'package:spend_tracker/models/transaction.dart';

void main() {
  test('rejects Meezan spend-and-win promo notification', () {
    final parser = TransactionParser();
    const body =
        'Apne Meezan Visa Classic Card se PKR 30,000 international spend karein '
        'aur Honda CD70 aur Yadea M3 eBike jeetne ka mauqa hasil karein. '
        "1 Jun-31 Aug'26. T&Cs apply.";
    final result = parser.parse(
      body,
      source: TransactionSource.notification,
      notificationTitle: 'Spend globally with Meezan Visa Card and Win Big!',
      packageName: 'com.meezanbank.mobile',
    );
    expect(result, isNull);
  });

  test('rejects crypto wallet chance-to-earn promo with dollar amount', () {
    final parser = TransactionParser();
    expect(
      parser.parse(
        'Buy any amount of ZBCN before 21st July for a chance to earn \$10 in ZBCN.',
        source: TransactionSource.notification,
        notificationTitle: 'Turn your Zebec into more 💸',
        packageName: 'com.zebec.wallet',
      ),
      isNull,
    );
  });

  test('rejects Meezan FX fee savings promo notification', () {
    final parser = TransactionParser();
    expect(
      parser.parse(
        'Apne Visa Card se International POS aur ATM par 0% FX Fee, '
        'jabke eCommerce par 1.99% FX Fee ka faida uthayein. '
        'Ye offer 31 July 2026 tak moassar hai. T&Cs apply.',
        source: TransactionSource.notification,
        notificationTitle: 'International Transactions par FX Fee mein Bachat!',
        packageName: 'com.meezanbank.mobile',
      ),
      isNull,
    );
  });

  test('rejects generic card promo with amount and prize wording', () {
    final parser = TransactionParser();
    expect(
      parser.parse(
        'Use your debit card for Rs. 10,000 shopping and win big prizes! '
        'Offer valid till 31 Dec. T&Cs apply.',
        source: TransactionSource.notification,
        notificationTitle: 'Shop & Win',
        packageName: 'com.ubluk.dc',
      ),
      isNull,
    );
  });

  group('rejects promos across finance apps', () {
    final parser = TransactionParser();

    test('JazzCash Roman Urdu load-and-win promo', () {
      expect(
        parser.parse(
          'Load karein Rs. 500 aur jeetein muft MBs! Offer valid till 31 July.',
          source: TransactionSource.notification,
          notificationTitle: 'JazzCash Offer',
          packageName: 'com.techlogix.mobilinkcustomer',
        ),
        isNull,
      );
    });

    test('Easypaisa spend-and-win card promo', () {
      expect(
        parser.parse(
          'Shop & Win! Spend Rs. 2,000 with your Easypaisa card and stand a '
          'chance to win an iPhone 17. T&Cs apply.',
          source: TransactionSource.notification,
          notificationTitle: 'Shop & Win with Easypaisa',
          packageName: 'pk.com.telenor.phoenix',
        ),
        isNull,
      );
    });

    test('NayaPay promo code discount push', () {
      expect(
        parser.parse(
          'Get up to Rs. 1,000 off on your first order with promo code '
          'NAYA100. Hurry, limited time only!',
          source: TransactionSource.notification,
          notificationTitle: 'A treat for you',
          packageName: 'com.nayapay.app',
        ),
        isNull,
      );
    });

    test('SadaPay upgrade-and-earn promo', () {
      expect(
        parser.parse(
          'Upgrade your card now and earn up to 5,000 points on every '
          'PKR 1,000 you spend!',
          source: TransactionSource.notification,
          notificationTitle: 'More rewards await',
          packageName: 'com.sadapay.wallet',
        ),
        isNull,
      );
    });

    test('HBL partner store discount promo', () {
      expect(
        parser.parse(
          'Avail exciting discounts of up to Rs. 3,000 with your HBL '
          'DebitCard at partner stores. Offer valid until 15 Aug.',
          source: TransactionSource.notification,
          notificationTitle: 'HBL DebitCard Discounts',
          packageName: 'com.hbl.android.hblmobilebanking',
        ),
        isNull,
      );
    });

    test('UBL lucky draw spend promo', () {
      expect(
        parser.parse(
          'Win a trip to Dubai! Spend PKR 50,000 on your UBL card this '
          'month. Lucky draw on 1 Sep. T&Cs apply.',
          source: TransactionSource.notification,
          notificationTitle: 'UBL Cards',
          packageName: 'com.ubluk.dc',
        ),
        isNull,
      );
    });

    test('Bank Alfalah Roman Urdu recharge promo', () {
      expect(
        parser.parse(
          'Apne Alfa account se Rs. 1,000 recharge karein aur muft data '
          'payein!',
          source: TransactionSource.notification,
          notificationTitle: 'Alfa',
          packageName: 'com.bankalfalah.alfa',
        ),
        isNull,
      );
    });

    test('SMS promo with amount and no package', () {
      expect(
        parser.parse(
          'Dial *123# and win Rs 10,000 balance! Valid till 30 July. '
          'T&Cs apply.',
          source: TransactionSource.sms,
        ),
        isNull,
      );
    });

    test('bank promo arriving via Gmail', () {
      expect(
        parser.parse(
          'Exclusive offer: earn up to PKR 5,000 in rewards when you shop '
          'with your card. Sign up now!',
          source: TransactionSource.notification,
          notificationTitle: 'Your bank rewards',
          packageName: 'com.google.android.gm',
        ),
        isNull,
      );
    });
  });

  group('genuine alerts with promo-adjacent words still parse', () {
    final parser = TransactionParser();

    test('debit at merchant named Win with trx id', () {
      final result = parser.parse(
        'You paid Rs 300.00 at Win Supermart using your card. '
        'Trx ID: 998877.',
        source: TransactionSource.notification,
        notificationTitle: 'Meezan Bank Alert',
        packageName: 'com.meezanbank.mobile',
      );
      expect(result, isNotNull);
      expect(result!.amount, 300.0);
    });

    test('reward credited to account is a real credit', () {
      final result = parser.parse(
        'Congratulations! Rs. 500.00 reward has been credited to your '
        'Easypaisa account. Available balance Rs. 2,500.00.',
        source: TransactionSource.notification,
        notificationTitle: 'Easypaisa',
        packageName: 'pk.com.telenor.phoenix',
      );
      expect(result, isNotNull);
      expect(result!.amount, 500.0);
      expect(result.type, TransactionType.credit);
    });

    test('debit alert with helpdesk Urdu tail still parses', () {
      final result = parser.parse(
        'Rs. 1,200.00 debited from your account for POS purchase at '
        'CARREFOUR. Available balance Rs. 9,000.',
        source: TransactionSource.notification,
        notificationTitle: 'HBL Account Alert',
        packageName: 'com.hbl.android.hblmobilebanking',
      );
      expect(result, isNotNull);
      expect(result!.amount, 1200.0);
      expect(result.type, TransactionType.debit);
    });
  });

  test('still accepts a genuine Meezan debit alert', () {
    final parser = TransactionParser();
    final result = parser.parse(
      'Dear Customer, your account has been debited by PKR 1,500.00 '
      'via POS purchase at CARREFOUR KHI on 14-Jul-26.',
      source: TransactionSource.notification,
      notificationTitle: 'Meezan Bank Alert',
      packageName: 'com.meezanbank.mobile',
    );
    expect(result, isNotNull);
    expect(result!.amount, 1500.0);
  });
}
