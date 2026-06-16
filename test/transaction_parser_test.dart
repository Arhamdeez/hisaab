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

  test('keeps a valid in-range date from the message', () {
    final result = parser.parse(
      'Rs 500 debited from A/c **4521 on 16-06-26 at SWIGGY',
      source: TransactionSource.sms,
      fallbackTime: DateTime(2026, 6, 20, 9, 30),
    );
    expect(result, isNotNull);
    expect(result!.occurredAt, DateTime(2026, 6, 16));
  });

  test('ignores reference numbers that look like dates', () {
    // "1234-56-7890" must not be misread as a date and file the transaction
    // into a bogus month — it should fall back to the message time.
    final fallback = DateTime(2026, 6, 16, 14, 0);
    final result = parser.parse(
      'Rs 200 spent at Cafe Ref 1234-56-7890',
      source: TransactionSource.notification,
      fallbackTime: fallback,
    );
    expect(result, isNotNull);
    expect(result!.occurredAt, fallback);
  });

  test('ignores future dates and falls back to the message time', () {
    final fallback = DateTime(2026, 6, 16, 14, 0);
    final result = parser.parse(
      'Rs 200 spent at Cafe on 16-06-40',
      source: TransactionSource.notification,
      fallbackTime: fallback,
    );
    expect(result, isNotNull);
    expect(result!.occurredAt, fallback);
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
