import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/core/utils/formatters.dart';

void main() {
  group('transactionAmountInputError', () {
    test('rejects negative amounts', () {
      expect(transactionAmountInputError('-1'), 'Amount cannot be negative');
      expect(transactionAmountInputError('-0.5'), 'Amount cannot be negative');
    });

    test('rejects zero', () {
      expect(transactionAmountInputError('0'), 'Amount must be greater than 0');
      expect(transactionAmountInputError('0.0'), 'Amount must be greater than 0');
    });

    test('accepts positive amounts', () {
      expect(transactionAmountInputError('500'), isNull);
      expect(transactionAmountInputError('1,250.50'), isNull);
      expect(transactionAmountInputError('0.01'), isNull);
    });

    test('rejects empty and invalid text', () {
      expect(transactionAmountInputError(''), 'Required');
      expect(transactionAmountInputError('abc'), 'Enter a valid amount');
    });
  });

  group('parseTransactionAmountInput', () {
    test('returns parsed positive amount', () {
      expect(parseTransactionAmountInput('2,500'), 2500);
      expect(parseTransactionAmountInput('99.5'), 99.5);
    });

    test('returns null for non-positive values', () {
      expect(parseTransactionAmountInput('-10'), isNull);
      expect(parseTransactionAmountInput('0'), isNull);
      expect(parseTransactionAmountInput(''), isNull);
    });
  });
}
