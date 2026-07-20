import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/features/parser/transaction_parser.dart';
import 'package:spend_tracker/models/transaction.dart';

void main() {
  final parser = TransactionParser();

  test('rejects ePay Punjab traffic challan generated (not paid)', () {
    const body =
        'Your Traffic Challan PSID:492618059329611884 is generated using '
        'ePay Punjab on 19–Jul–2026 for payment of Rs.2000 against vehicle '
        'number AZS 5648';
    expect(
      parser.parse(
        body,
        source: TransactionSource.notification,
        notificationTitle: 'Original message',
      ),
      isNull,
    );
  });

  test('rejects challan generated SMS without epay wording', () {
    expect(
      parser.parse(
        'Traffic Challan PSID:123456789012345678 is generated on 19-Jul-2026 '
        'for payment of Rs.1500 against vehicle number ABC 1234',
        source: TransactionSource.sms,
      ),
      isNull,
    );
  });

  test('still parses actual challan payment debit', () {
    final result = parser.parse(
      'PKR 2,000.00 has been debited from your A/C **1234 for Traffic Challan '
      'PSID 492618059329611884 payment on 19-Jul-2026 at 18:20',
      source: TransactionSource.notification,
      notificationTitle: 'Transaction Alert',
      packageName: 'com.meezanbank.mobile',
    );
    expect(result, isNotNull);
    expect(result!.amount, 2000);
    expect(result.type, TransactionType.debit);
  });

  test('parses paid Punjab Traffic Challan bill as transport debit', () {
    const body =
        'Punjab Traffic Challan bill for 492618059329611884 of Rs 2,015.00 '
        'due by 19–07–2026 has been paid on 19–07–2026. Fee+FED: Rs 0.00, '
        'TID: 718023708469';
    final result = parser.parse(
      body,
      source: TransactionSource.notification,
      notificationTitle: 'Original message',
    );

    expect(result, isNotNull);
    expect(result!.amount, 2015);
    expect(result.type, TransactionType.debit);
    expect(result.merchant, 'Punjab Traffic Challan');
    expect(result.category, SpendingCategory.transport);
    expect(result.referenceId, '718023708469');
  });
}
