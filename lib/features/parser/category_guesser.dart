import '../../models/transaction.dart';

class CategoryGuesser {
  static SpendingCategory guess(String text) {
    final lower = text.toLowerCase();
    const rules = <SpendingCategory, List<String>>{
      SpendingCategory.food: [
        'swiggy',
        'zomato',
        'restaurant',
        'cafe',
        'food',
        'dominos',
        'mcdonald',
      ],
      SpendingCategory.transport: [
        'uber',
        'ola',
        'rapido',
        'metro',
        'fuel',
        'petrol',
        'irctc',
      ],
      SpendingCategory.shopping: [
        'amazon',
        'flipkart',
        'myntra',
        'meesho',
        'shop',
      ],
      SpendingCategory.bills: [
        'electricity',
        'rent',
        'bill',
        'recharge',
        'jio',
        'airtel',
        'bescom',
      ],
      SpendingCategory.entertainment: [
        'netflix',
        'spotify',
        'prime',
        'hotstar',
        'movie',
      ],
      SpendingCategory.health: [
        'pharmacy',
        'apollo',
        'hospital',
        'medical',
        'health',
      ],
    };

    for (final entry in rules.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) return entry.key;
      }
    }
    return SpendingCategory.other;
  }
}
