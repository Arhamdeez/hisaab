import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/features/parser/category_guesser.dart';
import 'package:spend_tracker/models/transaction.dart';

void main() {
  group('CategoryGuesser PK fuel stations', () {
    test('maps common pump brands to transport', () {
      final samples = [
        'VALENCIA SERVICE STATION Lahore',
        'PSO Petrol Pump DHA',
        'Shell Pakistan',
        'Total Parco Filling Station',
        'Attock Petroleum',
        'GO Petroleum Gulberg',
        'Byco Energy',
        'Cnergyico Station',
        'Hascol Pump',
        'BE Energy',
        'Askar Oil',
        'Puma Energy PK',
        'Aramco Fuel Station',
        'Caltex Filling Station',
        'CNG Station Johar Town',
      ];
      for (final merchant in samples) {
        expect(
          CategoryGuesser.guess(merchant),
          SpendingCategory.transport,
          reason: merchant,
        );
      }
    });

    test('suggests transport from easypaisa fuel SMS text', () {
      final suggestion = CategoryGuesser.suggest(
        merchant: 'VALENCIA SERVICE STATION Lahore',
        rawText:
            'You have paid Rs. 460.00 at VALENCIA SERVICE STATION Lahore PK on 2026-07-13.',
      );
      expect(suggestion.categoryId, SpendingCategory.transport.storageKey);
      expect(suggestion.isConfident, isTrue);
    });
  });

  group('CategoryGuesser clothing and shoes', () {
    test('maps apparel brands to clothing', () {
      for (final merchant in [
        'Outfitters Packages',
        'Khaadi DHA',
        'Sapphire',
        'Limelight',
        'Breakout',
        'Gul Ahmed Ideas',
        'Nishat Linen',
        'Bareeze',
        'Myntra Order',
        'Zara',
      ]) {
        expect(
          CategoryGuesser.guess(merchant),
          SpendingCategory.clothing,
          reason: merchant,
        );
      }
    });

    test('maps footwear brands to shoes', () {
      for (final merchant in [
        'Bata Pakistan',
        'Servis Shoes',
        'Borjan',
        'Ndure',
        'Stylo Shoes',
        'Metro Shoes',
        'Nike Store',
        'Adidas',
        'Hush Puppies',
      ]) {
        expect(
          CategoryGuesser.guess(merchant),
          SpendingCategory.shoes,
          reason: merchant,
        );
      }
    });

    test('keeps general retail in shopping', () {
      expect(CategoryGuesser.guess('Daraz'), SpendingCategory.shopping);
      expect(CategoryGuesser.guess('Amazon'), SpendingCategory.shopping);
    });

    test('puma energy stays transport not shoes', () {
      expect(
        CategoryGuesser.guess('Puma Energy Filling Station'),
        SpendingCategory.transport,
      );
    });
  });

  group('CategoryGuesser PK food', () {
    test('maps fast food and local restaurants to food', () {
      final samples = [
        'KFC Gulberg',
        "McDonald's DHA",
        'Burger King Packages',
        'Pizza Hut',
        "Domino's Pizza",
        'Cheezious Lahore',
        'Howdy Burger',
        'OPTP Johar Town',
        'Bundu Khan BBQ',
        "Salt'n Pepper",
        'Student Biryani',
        'Johny and Jugnu',
        'Cakes and Bakes',
        'Foodpanda Order',
        'Hyperstar Defence',
        'Chase Up Supermarket',
        'Alfatah',
        'Shawarma Point',
        'Fri Chicks',
      ];
      for (final merchant in samples) {
        expect(
          CategoryGuesser.guess(merchant),
          SpendingCategory.food,
          reason: merchant,
        );
      }
    });
  });

  group('CategoryGuesser PK pharmacies', () {
    test('maps pharmacy brands to pharmacy not health', () {
      final samples = [
        'Servaid Pharmacy DHA',
        'Fazal Din Pharma Plus',
        'Dawaai.pk',
        'Green Plus Pharmacy',
        'Mahmood Pharmacy',
        'Shaheen Chemist',
        'Local Medical Store',
        'Dawakhana Noor',
      ];
      for (final merchant in samples) {
        expect(
          CategoryGuesser.guess(merchant),
          SpendingCategory.pharmacy,
          reason: merchant,
        );
      }
    });

    test('keeps hospitals in health', () {
      expect(
        CategoryGuesser.guess('Agha Khan University Hospital'),
        SpendingCategory.health,
      );
      expect(
        CategoryGuesser.guess('Chughtai Lab'),
        SpendingCategory.health,
      );
    });
  });

  group('CategoryGuesser entertainment', () {
    test('maps cinemas streaming and gaming to entertainment', () {
      for (final merchant in [
        'Cinepax Packages Mall',
        'Cue Cinemas Lahore',
        'Nueplex DHA',
        'Atrium Cinemas',
        'Universal Cinema',
        'Netflix',
        'Spotify Premium',
        'Amazon Prime',
        'YouTube Premium',
        'Disney Plus',
        'PlayStation Store',
        'Steam Purchase',
        'BookMyShow',
        'IMAX Karachi',
      ]) {
        expect(
          CategoryGuesser.guess(merchant),
          SpendingCategory.entertainment,
          reason: merchant,
        );
      }
    });
  });

  group('CategoryGuesser Others fallback', () {
    test('puts ambiguous or unknown merchants in Others', () {
      for (final merchant in [
        'Packages Mall',
        'ABC Store',
        'Local Shop',
        'XYZ Traders',
        'Unknown Merchant',
        'Bill Payment',
      ]) {
        expect(
          CategoryGuesser.guess(merchant),
          SpendingCategory.other,
          reason: merchant,
        );
      }
    });
  });
}
