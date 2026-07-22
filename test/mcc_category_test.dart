import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/features/parser/category_guesser.dart';
import 'package:spend_tracker/features/parser/mcc_catalog.dart';
import 'package:spend_tracker/features/parser/transaction_parser.dart';
import 'package:spend_tracker/models/transaction.dart';

void main() {
  group('MccCatalog.extract', () {
    test('reads common MCC label shapes', () {
      expect(MccCatalog.extract('Paid PKR 500 MCC: 5411 at METRO'), 5411);
      expect(MccCatalog.extract('Purchase MCC-5812 STARBUCKS'), 5812);
      expect(MccCatalog.extract('Txn MCC 5541 PSO'), 5541);
      expect(
        MccCatalog.extract('Merchant category code 5661 BATA'),
        5661,
      );
    });

    test('ignores text without an MCC', () {
      expect(MccCatalog.extract('You paid Rs 500 at KFC'), isNull);
    });
  });

  group('MccCatalog.categoryFor', () {
    test('maps grocery / dining / fuel / pharmacy / shoes', () {
      expect(MccCatalog.categoryFor(5411), SpendingCategory.food);
      expect(MccCatalog.categoryFor(5812), SpendingCategory.food);
      expect(MccCatalog.categoryFor(5814), SpendingCategory.food);
      expect(MccCatalog.categoryFor(5541), SpendingCategory.transport);
      expect(MccCatalog.categoryFor(5542), SpendingCategory.transport);
      expect(MccCatalog.categoryFor(5912), SpendingCategory.pharmacy);
      expect(MccCatalog.categoryFor(5661), SpendingCategory.shoes);
      expect(MccCatalog.categoryFor(5651), SpendingCategory.clothing);
      expect(MccCatalog.categoryFor(7832), SpendingCategory.entertainment);
      expect(MccCatalog.categoryFor(4900), SpendingCategory.bills);
      expect(MccCatalog.categoryFor(9222), SpendingCategory.transport);
    });

    test('maps Pakistan-frequent Visa / Mastercard / PayPak codes', () {
      // Groceries & everyday retail.
      expect(MccCatalog.categoryFor(5411), SpendingCategory.food);
      expect(MccCatalog.categoryFor(5462), SpendingCategory.food);
      expect(MccCatalog.categoryFor(5499), SpendingCategory.food);
      expect(MccCatalog.categoryFor(5311), SpendingCategory.shopping);
      expect(MccCatalog.categoryFor(5912), SpendingCategory.pharmacy);

      // Dining.
      expect(MccCatalog.categoryFor(5812), SpendingCategory.food);
      expect(MccCatalog.categoryFor(5814), SpendingCategory.food);

      // Fuel & ride-hailing.
      expect(MccCatalog.categoryFor(5541), SpendingCategory.transport);
      expect(MccCatalog.categoryFor(4121), SpendingCategory.transport);

      // Travel & aviation (incl. PIA / Emirates legacy airline MCCs).
      expect(MccCatalog.categoryFor(3024), SpendingCategory.transport);
      expect(MccCatalog.categoryFor(3026), SpendingCategory.transport);
      expect(MccCatalog.categoryFor(4511), SpendingCategory.transport);
      expect(MccCatalog.categoryFor(4722), SpendingCategory.transport);
      expect(MccCatalog.categoryFor(7011), SpendingCategory.transport);
      expect(MccCatalog.categoryFor(3030), SpendingCategory.transport); // airline band

      // Clothing.
      expect(MccCatalog.categoryFor(5651), SpendingCategory.clothing);
      expect(MccCatalog.categoryFor(5621), SpendingCategory.clothing);
      expect(MccCatalog.categoryFor(5691), SpendingCategory.clothing);

      // Digital / utilities / government / ATM.
      expect(MccCatalog.categoryFor(4814), SpendingCategory.bills);
      expect(MccCatalog.categoryFor(4900), SpendingCategory.bills);
      expect(MccCatalog.categoryFor(9399), SpendingCategory.bills);
      expect(MccCatalog.categoryFor(6513), SpendingCategory.bills);
      expect(MccCatalog.categoryFor(6011), SpendingCategory.other);
    });
  });

  group('CategoryGuesser keyword fallback unchanged', () {
    test('still categorizes PK merchants when no MCC is present', () {
      expect(CategoryGuesser.guess('KFC DHA'), SpendingCategory.food);
      expect(
        CategoryGuesser.guess('VALENCIA SERVICE STATION'),
        SpendingCategory.transport,
      );
      expect(CategoryGuesser.guess('Khaadi'), SpendingCategory.clothing);
      expect(CategoryGuesser.guess('DVAGO Pharmacy'), SpendingCategory.pharmacy);
      expect(CategoryGuesser.guess('Cinepax'), SpendingCategory.entertainment);
    });
  });

  group('CategoryGuesser MCC priority', () {
    test('MCC beats conflicting merchant keywords', () {
      // "store" / apparel-ish name would otherwise be ambiguous; MCC wins.
      expect(
        CategoryGuesser.guess('OUTFITTERS STORE MCC: 5812'),
        SpendingCategory.food,
      );
      expect(
        CategoryGuesser.guess('RANDOM MERCHANT MCC 5541'),
        SpendingCategory.transport,
      );
    });

    test('suggest reports MCC source', () {
      final suggestion = CategoryGuesser.suggest(
        merchant: 'SHELL',
        rawText: 'PKR 2,000.00 at SHELL MCC: 5542',
      );
      expect(suggestion.categoryId, SpendingCategory.transport.storageKey);
      expect(suggestion.source, CategorySuggestionSource.mcc);
      expect(suggestion.mcc, 5542);
    });

    test('history still beats MCC', () {
      final history = [
        Transaction(
          id: '1',
          amount: 100,
          type: TransactionType.debit,
          merchant: 'SHELL',
          categoryId: SpendingCategory.shopping.storageKey,
          occurredAt: DateTime(2026, 7, 1),
          source: TransactionSource.notification,
          status: TransactionStatus.confirmed,
          fingerprint: 'x',
        ),
      ];
      final suggestion = CategoryGuesser.suggest(
        merchant: 'SHELL',
        rawText: 'PKR 2,000.00 at SHELL MCC: 5542',
        confirmedHistory: history,
      );
      expect(suggestion.categoryId, SpendingCategory.shopping.storageKey);
      expect(suggestion.source, CategorySuggestionSource.history);
    });
  });

  group('TransactionParser MCC', () {
    test('attaches MCC and category from wallet alert text', () {
      final result = TransactionParser().parse(
        'PKR 1,250.00 with EP Digital Card Google Wallet ••8421 MCC: 5814',
        source: TransactionSource.notification,
        notificationTitle: 'KFC',
        packageName: 'com.google.android.apps.walletnfcrel',
      );
      expect(result, isNotNull);
      expect(result!.mcc, 5814);
      expect(result.category, SpendingCategory.food);
    });
  });
}
