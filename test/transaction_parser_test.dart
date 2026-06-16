import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/features/parser/transaction_parser.dart';
import 'package:spend_tracker/models/transaction.dart';

void main() {
  final parser = TransactionParser();

  test('parses HDFC debit SMS', () {
    final result = parser.parse(
      'Rs 500 debited from A/c **4521 on 16-06-26 at SWIGGY. Info: UPI/12345',
      source: TransactionSource.sms,
    );
    expect(result, isNotNull);
    expect(result!.amount, 500);
    expect(result.type, TransactionType.debit);
    expect(result.merchant.toLowerCase(), contains('swiggy'));
  });

  test('parses credit alert', () {
    final result = parser.parse(
      'INR 85,000 credited to A/c **1234 on salary',
      source: TransactionSource.gmail,
    );
    expect(result, isNotNull);
    expect(result!.amount, 85000);
    expect(result.type, TransactionType.credit);
  });

  test('builds stable fingerprint', () {
    final fp1 = TransactionParser.buildFingerprint(
      amount: 500,
      occurredAt: DateTime(2026, 6, 16),
      merchant: 'Swiggy',
      accountRef: '4521',
    );
    final fp2 = TransactionParser.buildFingerprint(
      amount: 500,
      occurredAt: DateTime(2026, 6, 16),
      merchant: 'swiggy',
      accountRef: '4521',
    );
    expect(fp1, fp2);
  });
}
