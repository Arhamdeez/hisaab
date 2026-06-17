import '../../models/transaction.dart';

enum CategorySuggestionSource {
  history,
  text,
  parsed,
  defaultOther,
}

class CategorySuggestion {
  const CategorySuggestion({
    required this.category,
    required this.source,
  });

  final SpendingCategory category;
  final CategorySuggestionSource source;

  bool get isConfident =>
      category != SpendingCategory.other &&
      source != CategorySuggestionSource.defaultOther;

  String get reasonLabel => switch (source) {
        CategorySuggestionSource.history =>
          'Same merchant before · ${category.label}',
        CategorySuggestionSource.text =>
          'Detected from details · ${category.label}',
        CategorySuggestionSource.parsed =>
          'Parser guess · ${category.label}',
        CategorySuggestionSource.defaultOther => 'Choose a category',
      };
}

class CategoryGuesser {
  static const _rules = <SpendingCategory, List<String>>{
    SpendingCategory.food: [
      'swiggy',
      'zomato',
      'restaurant',
      'cafe',
      'food',
      'dominos',
      'mcdonald',
      'grocery',
      'groceries',
      'lunch',
      'dinner',
      'breakfast',
      'eat',
      'meal',
      'kfc',
      'pizza',
    ],
    SpendingCategory.transport: [
      'uber',
      'ola',
      'careem',
      'rapido',
      'metro',
      'fuel',
      'petrol',
      'diesel',
      'irctc',
      'taxi',
      'bus',
      'parking',
      'toll',
    ],
    SpendingCategory.shopping: [
      'amazon',
      'flipkart',
      'myntra',
      'meesho',
      'shop',
      'mall',
      'store',
      'daraz',
    ],
    SpendingCategory.bills: [
      'electricity',
      'rent',
      'bill',
      'bills',
      'recharge',
      'jio',
      'airtel',
      'bescom',
      'internet',
      'wifi',
      'utility',
      'housing',
      'k-electric',
      'kelectric',
      'sui gas',
      'gas bill',
    ],
    SpendingCategory.entertainment: [
      'netflix',
      'spotify',
      'prime',
      'hotstar',
      'movie',
      'cinema',
      'game',
      'youtube',
    ],
    SpendingCategory.health: [
      'pharmacy',
      'apollo',
      'hospital',
      'medical',
      'health',
      'clinic',
      'doctor',
      'gym',
    ],
  };

  static SpendingCategory guess(String text) {
    final lower = text.toLowerCase();
    for (final entry in _rules.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) return entry.key;
      }
    }
    return SpendingCategory.other;
  }

  /// Picks the best category using past confirmed spends, then merchant text.
  static CategorySuggestion suggest({
    required String merchant,
    String? rawText,
    String? userNote,
    SpendingCategory? parsedCategory,
    Iterable<Transaction>? confirmedHistory,
  }) {
    final history = _fromHistory(merchant, confirmedHistory);
    if (history != null) {
      return CategorySuggestion(
        category: history,
        source: CategorySuggestionSource.history,
      );
    }

    final blob = [
      merchant,
      ?rawText,
      ?userNote,
    ].join(' ');
    final fromText = guess(blob);
    if (fromText != SpendingCategory.other) {
      return CategorySuggestion(
        category: fromText,
        source: CategorySuggestionSource.text,
      );
    }

    if (parsedCategory != null &&
        parsedCategory != SpendingCategory.other) {
      return CategorySuggestion(
        category: parsedCategory,
        source: CategorySuggestionSource.parsed,
      );
    }

    return const CategorySuggestion(
      category: SpendingCategory.other,
      source: CategorySuggestionSource.defaultOther,
    );
  }

  static SpendingCategory? _fromHistory(
    String merchant,
    Iterable<Transaction>? history,
  ) {
    if (history == null) return null;

    final needle = _normalizeMerchant(merchant);
    if (needle.isEmpty) return null;

    final counts = <SpendingCategory, int>{};
    for (final tx in history) {
      if (!tx.isDebit || tx.status != TransactionStatus.confirmed) continue;
      if (!_merchantsMatch(needle, _normalizeMerchant(tx.merchant))) continue;
      counts[tx.category] = (counts[tx.category] ?? 0) + 1;
    }

    if (counts.isEmpty) return null;

    return counts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  static String _normalizeMerchant(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  static bool _merchantsMatch(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b) return true;
    if (a.contains(b) || b.contains(a)) return true;
    return false;
  }
}
