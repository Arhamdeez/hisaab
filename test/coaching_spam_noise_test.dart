import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/features/parser/transaction_parser.dart';
import 'package:spend_tracker/models/transaction.dart';

void main() {
  final parser = TransactionParser();

  const coachingBody =
      "Antoine — Wahb You're FREE Invitation\n"
      'Hey Wahb,\n'
      "I wanted to personally invite you to this week's FREE coaching call.\n"
      'Completely free.\n'
      'No catch.\n'
      "Just an opportunity to get direct feedback on your agency from someone "
      "who's spent the last 7 years helping agencies generate over \$30M in "
      'client revenue through cold outreach.\n'
      'One of the biggest reasons agencies stay stuck at \$0 — \$10k/month '
      "isn't because they aren't working hard.\n"
      'Leave the call with a clear plan to book more qualified sales calls, '
      'sign more \$2k+ retainer clients, and move closer to your first (or next) '
      '\$10k — \$50k/month.';

  test('rejects FREE coaching call invite with \$ revenue figures', () {
    expect(
      parser.parse(
        coachingBody,
        source: TransactionSource.notification,
        notificationTitle: "Wahb You're FREE Invitation",
        packageName: 'com.google.android.gm',
      ),
      isNull,
    );
  });

  test('does not treat \$30M marketing copy as amount 3', () {
    expect(
      parser.parse(
        "someone who's spent years helping agencies generate over \$30M "
        'in client revenue',
        source: TransactionSource.notification,
        notificationTitle: 'Growth tip',
        packageName: 'com.google.android.gm',
      ),
      isNull,
    );
  });

  test('still parses real USD wallet payment', () {
    final result = parser.parse(
      r'You sent $25.00 to Coffee Shop — Google Wallet',
      source: TransactionSource.notification,
      notificationTitle: 'Google Wallet',
      packageName: 'com.google.android.apps.walletnfcrel',
    );
    expect(result, isNotNull);
    expect(result!.amount, 25.0);
  });
}
