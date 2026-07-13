import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/features/parser/transaction_parser.dart';
import 'package:spend_tracker/models/transaction.dart';

void main() {
  test('rejects Meezan login successful security notification', () {
    final parser = TransactionParser();
    const body =
        'Login Successful — You have successfully logged in to Meezan bank Mobile App. '
        'If you do not recognize this login attempt, please immediately call our 24/7 '
        'helpline at +92 21 111 — 331 — 331 / 111 — 331 — 332 to block the Mobile Banking services.';
    final result = parser.parse(
      body,
      source: TransactionSource.notification,
      notificationTitle: 'Login Successful',
      packageName: 'com.meezanbank.mobile',
    );
    expect(result, isNull);
  });

  test('rejects UBL new device login alert', () {
    final parser = TransactionParser();
    expect(
      parser.parse(
        'New device login detected on your UBL Digital account. '
        'If this was not you, call our helpline immediately.',
        source: TransactionSource.notification,
        notificationTitle: 'Security Alert',
        packageName: 'com.ubluk.dc',
      ),
      isNull,
    );
  });
}
