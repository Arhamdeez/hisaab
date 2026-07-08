import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/features/parser/transaction_parser.dart';
import 'package:spend_tracker/models/transaction.dart';

void main() {
  final parser = TransactionParser();

  group('rejects wallet marketing promos', () {
    test('rejects Yeylo cashback offer', () {
      expect(
        parser.parse(
          'Yeylo, 50% cashback on LAAM — Get upto 6,000 cashback on LAAM only with Yeylo!',
          source: TransactionSource.notification,
          packageName: 'pk.com.telenor.phoenix',
        ),
        isNull,
      );
    });

    test('rejects Yeylo cashback offer when brand is notification title', () {
      expect(
        parser.parse(
          'Yeylo, 50% cashback on LAAM — Get upto 6,000 cashback on LAAM only with Yeylo!',
          source: TransactionSource.notification,
          packageName: 'pk.com.telenor.phoenix',
          notificationTitle: 'Yeylo',
        ),
        isNull,
      );
    });

    test('rejects Reward Hub join promo', () {
      expect(
        parser.parse(
          'Rewards aap ka intezar kar rahe hain ! — Aap Reward Hub rewards ke liye eligible hain! Rs.99 mein join karein.',
          source: TransactionSource.notification,
          packageName: 'pk.com.telenor.phoenix',
        ),
        isNull,
      );
    });

    test('rejects Reward Hub join promo when hub is notification title', () {
      expect(
        parser.parse(
          'Rewards aap ka intezar kar rahe hain ! — Aap Reward Hub rewards ke liye eligible hain! Rs.99 mein join karein.',
          source: TransactionSource.notification,
          packageName: 'pk.com.telenor.phoenix',
          notificationTitle: 'Reward Hub',
        ),
        isNull,
      );
    });

    test('still accepts real cashback credit', () {
      final result = parser.parse(
        'You received Rs. 50 cashback in your Easypaisa account.',
        source: TransactionSource.notification,
        packageName: 'pk.com.telenor.phoenix',
      );
      expect(result, isNotNull);
      expect(result!.amount, 50);
      expect(result.type, TransactionType.credit);
    });
  });
}
