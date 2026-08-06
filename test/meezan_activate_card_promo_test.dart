import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/features/parser/transaction_parser.dart';
import 'package:spend_tracker/models/transaction.dart';

void main() {
  final parser = TransactionParser();

  test('rejects Meezan activate MasterCard travel promo with helpline /332', () {
    expect(
      parser.parse(
        'Travelling Abroad? Activate Your MasterCard! — '
        'Don’t forget to activate your MasterCard for international transactions '
        'before you travel. Activate it conveniently through the Meezan Mobile App '
        'or call at 021–111–331–331/332. — invo8.meezan.mb — '
        'campaign_collapse_key_4816433549138353547',
        source: TransactionSource.notification,
        notificationTitle: 'Travelling Abroad? Activate Your MasterCard!',
        packageName: 'com.meezanbank.mobile',
      ),
      isNull,
    );
  });

  test('still parses genuine Meezan debit with TID', () {
    final result = parser.parse(
      'Meezan Bank Alert — PKR 332.00 sent to ALI KHAN as RAAST '
      'payment from your AC# xxx3625 on 31 — Jul — 2026 at 19:05 TID:935776.',
      source: TransactionSource.notification,
      notificationTitle: 'Meezan Bank Alert',
      packageName: 'com.meezanbank.mobile',
    );
    expect(result, isNotNull);
    expect(result!.amount, 332.0);
    expect(result.type, TransactionType.debit);
  });
}
