import '../../models/transaction.dart';
import '../../providers/category_catalog.dart';

enum CategorySuggestionSource {
  history,
  text,
  parsed,
  defaultOther,
}

class CategorySuggestion {
  const CategorySuggestion({
    required this.categoryId,
    required this.source,
  });

  final String categoryId;
  final CategorySuggestionSource source;

  bool get isConfident =>
      categoryId != SpendingCategory.other.storageKey &&
      source != CategorySuggestionSource.defaultOther;

  String get reasonLabel {
    final label = CategoryCatalog.instance.resolve(categoryId).label;
    return switch (source) {
      CategorySuggestionSource.history =>
        'Same merchant before · $label',
      CategorySuggestionSource.text => 'Detected from details · $label',
      CategorySuggestionSource.parsed => 'Parser guess · $label',
      CategorySuggestionSource.defaultOther => 'Choose a category',
    };
  }
}

class CategoryGuesser {
  static const _rules = <SpendingCategory, List<String>>{
    SpendingCategory.food: [
      // Generic food / dining.
      'restaurant',
      'resturant', // common SMS misspelling
      'cafe',
      'café',
      'coffee',
      'food',
      'fast food',
      'fastfood',
      'grocery',
      'groceries',
      'lunch',
      'dinner',
      'breakfast',
      'brunch',
      'meal',
      'biryani',
      'karahi',
      'bbq',
      'barbeque',
      'barbecue',
      'nihari',
      'haleem',
      'paratha',
      'shawarma',
      'burger',
      'pizza',
      'broast',
      'steak',
      'dessert',
      'bakery',
      'cake',
      'cakes',
      'bakes',
      'sweets',
      'mithai',
      'halwa',
      'dhaba',
      'tandoor',
      'tandoori',
      'chai',
      'juice',
      'icecream',
      'ice cream',
      // Delivery / aggregators.
      'foodpanda',
      'food panda',
      'swiggy',
      'zomato',
      'talabat',
      // International fast food (PK).
      'kfc',
      'mcdonald',
      "mcdonald's",
      'burger king',
      'hardee',
      'hardees',
      'subway',
      'domino',
      'pizza hut',
      'pizzahut',
      'papa john',
      "papa john's",
      'dunkin',
      'starbucks',
      'tim hortons',
      'nandos',
      "nando's",
      'taco bell',
      'wendy',
      'popeyes',
      'california pizza',
      'krispy kreme',
      'baskin',
      'gelato',
      'tutti frutti',
      // Local / regional PK chains.
      'cheezious',
      'howdy',
      'burger lab',
      'optp',
      'broadway pizza',
      '14th street',
      'fri chics',
      'fri chicks',
      'bundu khan',
      "salt'n pepper",
      'salt n pepper',
      'salt and pepper',
      'monal',
      'kolachi',
      'student biryani',
      'studentbiryani',
      'quetta cafe',
      'namak mandi',
      'butt karahi',
      'butt chicken',
      'hanifia',
      'usmania',
      'shawarma point',
      'ginsoy',
      'tokyo express',
      'yayvo',
      'kaybees',
      'kay bees',
      'johnny and jugnu',
      'johny and jugnu',
      'johnny & jugnu',
      'johny & jugnu',
      'jugnu',
      'cakes and bakes',
      'cakes & bakes',
      'hot n spicy',
      'hot and spicy',
      'ranchers',
      'xinjiang',
      'fork n knives',
      'fork and knives',
      'arcadian cafe',
      'jade cafe',
      'second cup',
      'gloria jean',
      "gloria jean's",
      'coffee planet',
      // Marts / grocery (PK) — avoid bare "mart" (matches "smart").
      'hyperstar',
      'carrefour',
      'chase up',
      'chaseup',
      'alfatah',
      'al-fatah',
      'imtiyaz',
      'naheed',
      'metro cash',
      'cash and carry',
      'cash & carry',
      'superstore',
      'super store',
      'supermart',
      'super mart',
      'utility store',
      'utility stores',
      'greenvalley',
      'green valley',
      'jalal sons',
    ],
    SpendingCategory.transport: [
      'uber',
      'ola',
      'careem',
      'rapido',
      // Avoid bare "metro" — conflicts with Metro Shoes.
      'metro bus',
      'metro station',
      'orange line',
      'green line',
      'fuel',
      'petrol',
      'diesel',
      'cng',
      'irctc',
      'taxi',
      'bus',
      'parking',
      'toll',
      // Pakistan fuel / filling stations (POS & SMS merchant names).
      'pso',
      'pakistan state oil',
      'shell',
      'total parco',
      'total petrol',
      'attock',
      'apl petroleum',
      'go petroleum',
      'go pump',
      'byco',
      'cnergyico',
      'hascol',
      'be energy',
      'be petroleum',
      'askar',
      'zoom petroleum',
      'puma energy',
      'puma petroleum',
      'aramco',
      'caltex',
      'filling station',
      'service station',
      'fuel station',
      'petrol pump',
      'petroleum',
    ],
    // Before Shopping — otherwise "medical store" matches Shopping's "store".
    SpendingCategory.pharmacy: [
      'pharmacy',
      'pharmacies',
      'chemist',
      'medical store',
      'medicalstore',
      'dawakhana',
      'dawa khana',
      'medicine',
      'medicines',
      // Pakistan pharmacy chains & e-pharmacies.
      'servaid',
      'fazal din',
      'fazaldin',
      'pharma plus',
      'pharmaplus',
      'dawaai',
      'dawaai.pk',
      'green plus',
      'greenplus',
      'clinix',
      'mahmood pharmacy',
      'shaheen chemist',
      'mediplus',
      'healthplus',
      'health plus',
      'timing pharmacy',
      'opal pharmacy',
      'bootstrap pharmacy',
      'quick pharmacy',
      'kims pharmacy',
      'ailaaj',
      'dvago',
      'apollo',
    ],
    SpendingCategory.health: [
      'hospital',
      'medical',
      'health',
      'clinic',
      'doctor',
      'gym',
      'lab',
      'laboratory',
      'diagnostic',
      'chughtai',
      'agha khan',
      'aga khan',
      'shifa',
    ],
    // Fashion before Shopping so brand "… store" hits Clothing/Shoes first.
    SpendingCategory.clothing: [
      'clothing',
      'clothes',
      'apparel',
      'garment',
      'fashion',
      'boutique',
      'linen',
      'lawn',
      'pret',
      'unstitched',
      'stitched',
      'kurta',
      'kurti',
      'shalwar',
      'kameez',
      // PK clothing / fashion brands.
      'outfitters',
      'breakout',
      'limelight',
      'khaadi',
      'sapphire',
      'gul ahmed',
      'gulahmed',
      'ideas by gul',
      'alkaram',
      'nishat linen',
      'nishatlinen',
      'bareeze',
      'chenone',
      'chen one',
      'bonanza',
      'satrangi',
      'sana safinaz',
      'maria b',
      'cross stitch',
      'ethnic',
      'generation',
      'diners',
      'leisure club',
      'charcoal clothing',
      'charcoal store',
      'cambridge',
      'junaid jamshed',
      'ideas store',
      'hunza',
      'kayseria',
      'beechtree',
      'beech tree',
      'style textile',
      'engine clothing',
      // International apparel.
      'myntra',
      'meesho',
      'zara',
      'h&m',
      'h & m',
      'mango',
      'levis',
      "levi's",
      'uniqlo',
      'cotton on',
      'forever 21',
      'tommy hilfiger',
      'calvin klein',
      'ralph lauren',
      'nike apparel',
      'adidas apparel',
    ],
    SpendingCategory.shoes: [
      'shoe',
      'shoes',
      'footwear',
      'sneaker',
      'sneakers',
      'sandal',
      'sandals',
      'boots',
      // PK footwear brands.
      'bata',
      'servis',
      'borjan',
      'ndure',
      'stylo',
      'metro shoes',
      'unze',
      'hush puppies',
      'ecs shoes',
      'shoe planet',
      'shoes & shoes',
      'shoes and shoes',
      // International footwear / sportswear.
      'nike',
      'adidas',
      'puma',
      'reebok',
      'new balance',
      'skechers',
      'converse',
      'crocs',
      'clarks',
      'timberland',
      'under armour',
      'asics',
      'fila',
    ],
    // Before shopping so "mall/store/amazon" don't steal cinema & streaming.
    SpendingCategory.entertainment: [
      // Generic entertainment.
      'movie',
      'movies',
      'cinema',
      'cinemas',
      'theatre',
      'theater',
      'concert',
      'movie ticket',
      'cinema ticket',
      'gaming',
      'arcade',
      'bowling',
      'amusement',
      'theme park',
      'funland',
      // Streaming / digital media.
      'netflix',
      'spotify',
      'prime video',
      'amazon prime',
      'hotstar',
      'disney+',
      'disney plus',
      'youtube',
      'youtube premium',
      'youtube music',
      'apple music',
      'apple tv',
      'tidal',
      'deezer',
      'twitch',
      'patreon',
      // PK cinema chains & venues.
      'cinepax',
      'cine star',
      'cinestar',
      'cue cinema',
      'cue cinemas',
      'nueplex',
      'capri cinema',
      'atrium cinema',
      'atrium cinemas',
      'mega multiplex',
      'megaplex',
      'universal cinema',
      'the arena',
      'arena cinema',
      'super cinema',
      'royal cinema',
      'nishat cinema',
      'prince cinema',
      'plaza cinema',
      'centaurus cinema',
      'pak cinema',
      'imax',
      // Events / tickets / leisure.
      'bookmyshow',
      'book my show',
      'ticketwala',
      'playland',
      'wonderland',
      'sozo water',
      'go kart',
      'gokart',
      'laser tag',
      'escape room',
      // Gaming.
      'playstation',
      'xbox',
      'steam',
      'nintendo',
      'pubg',
      'freefire',
      'free fire',
      'gamestop',
      'game stop',
    ],
    SpendingCategory.shopping: [
      // Specific retailers only — bare shop/mall/store are too ambiguous → Others.
      'amazon',
      'flipkart',
      'daraz',
      'miniso',
      'homeware',
      'electronics',
      'mobile shop',
      'mobile store',
      'laptop',
      'shopping',
    ],
    SpendingCategory.bills: [
      // Avoid bare "bill" — bank SMS often says "bill payment" for any spend.
      'electricity',
      'electric bill',
      'rent',
      'utility bill',
      'gas bill',
      'water bill',
      'recharge',
      'jio',
      'airtel',
      'bescom',
      'internet bill',
      'wifi bill',
      'utility',
      'housing',
      'k-electric',
      'kelectric',
      'sui gas',
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
        categoryId: history,
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
        categoryId: fromText.storageKey,
        source: CategorySuggestionSource.text,
      );
    }

    if (parsedCategory != null &&
        parsedCategory != SpendingCategory.other) {
      return CategorySuggestion(
        categoryId: parsedCategory.storageKey,
        source: CategorySuggestionSource.parsed,
      );
    }

    return CategorySuggestion(
      categoryId: SpendingCategory.other.storageKey,
      source: CategorySuggestionSource.defaultOther,
    );
  }

  static String? _fromHistory(
    String merchant,
    Iterable<Transaction>? history,
  ) {
    if (history == null) return null;

    final needle = _normalizeMerchant(merchant);
    if (needle.isEmpty) return null;

    final counts = <String, int>{};
    for (final tx in history) {
      if (!tx.isDebit || tx.status != TransactionStatus.confirmed) continue;
      if (!_merchantsMatch(needle, _normalizeMerchant(tx.merchant))) continue;
      counts[tx.categoryId] = (counts[tx.categoryId] ?? 0) + 1;
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
