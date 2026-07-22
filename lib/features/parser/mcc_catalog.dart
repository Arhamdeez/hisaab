import '../../models/transaction.dart';

/// ISO 18245 merchant category codes → HISAAB [SpendingCategory].
///
/// Used by Visa, Mastercard, and Pakistan’s 1Link / PayPak rails. Bank apps
/// (Meezan, HBL, Alfalah, …) and POS/statement lines sometimes print
/// `MCC: 5411` / `MCC 5814`. When an MCC is present it wins; otherwise the
/// existing keyword guesser is unchanged.
abstract final class MccCatalog {
  /// Pulls a 4-digit MCC from alert / SMS / statement text.
  static int? extract(String text) {
    if (text.trim().isEmpty) return null;
    final match = _mccInText.firstMatch(text);
    if (match == null) return null;
    final code = int.tryParse(match.group(1)!);
    if (code == null || code < 1000 || code > 9999) return null;
    return code;
  }

  /// Maps an MCC to a spend bucket. Unknown codes → [SpendingCategory.other].
  static SpendingCategory categoryFor(int mcc) {
    final exact = _exact[mcc];
    if (exact != null) return exact;

    for (final range in _ranges) {
      if (mcc >= range.$1 && mcc <= range.$2) return range.$3;
    }
    return SpendingCategory.other;
  }

  /// Extract + map. Returns null when there is no MCC (so keywords can run).
  ///
  /// Explicit ATM / unknown-other codes that are listed in [_exact] still
  /// return [SpendingCategory.other] so keywords cannot override them.
  static SpendingCategory? categoryFromText(String text) {
    final mcc = extract(text);
    if (mcc == null) return null;
    final category = categoryFor(mcc);
    if (category != SpendingCategory.other) return category;
    if (_exact.containsKey(mcc)) return category;
    return null;
  }

  // Visa / Mastercard / PayPak style: "MCC: 5411", "MCC-5812", "merchant category 5541".
  static final _mccInText = RegExp(
    r'\b(?:mcc|merchant\s+categor(?:y|ies)\s*code)\s*[:=\-\s#]*\s*(\d{4})\b',
    caseSensitive: false,
  );

  /// Exact codes. Pakistan-frequent codes (Visa / Mastercard / 1Link / PayPak)
  /// are listed first with local merchant examples in comments.
  static const _exact = <int, SpendingCategory>{
    // —— Pakistan-priority: groceries & everyday retail ——
    5411: SpendingCategory.food, // Supermarkets (Carrefour, Chase Up, Metro, Imtiaz)
    5462: SpendingCategory.food, // Bakeries (Gourmet, Tehzeeb, United King)
    5499: SpendingCategory.food, // Misc food / local convenience marts
    5311: SpendingCategory.shopping, // Department stores (Al-Fatah, Jalal Sons)
    5912: SpendingCategory.pharmacy, // Pharmacies (Fazal Din, D-Watson, DVAGO)

    // —— Pakistan-priority: dining / fast food / delivery ——
    5812: SpendingCategory.food, // Restaurants (fine / casual)
    5814: SpendingCategory.food, // Fast food (McD, KFC) + Foodpanda-class delivery

    // —— Pakistan-priority: fuel & ride-hailing ——
    5541: SpendingCategory.transport, // Fuel (Total Parco, Shell, PSO, Hascol)
    4121: SpendingCategory.transport, // Taxicabs (Careem, Yango, inDrive)

    // —— Pakistan-priority: travel & aviation ——
    3024: SpendingCategory.transport, // Pakistan International Airlines (PIA)
    3026: SpendingCategory.transport, // Emirates
    4511: SpendingCategory.transport, // Airlines (AirSial, Fly Jinnah, Air Indus)
    4722: SpendingCategory.transport, // Travel agencies (Sastaticket)
    7011: SpendingCategory.transport, // Hotels / resorts (PC, Serena)

    // —— Pakistan-priority: clothing / fashion ——
    5651: SpendingCategory.clothing, // Family clothing (Khaadi, J., Sapphire, Gul Ahmed)
    5621: SpendingCategory.clothing, // Women’s ready-to-wear
    5691: SpendingCategory.clothing, // Men’s & women’s clothing stores

    // —— Pakistan-priority: digital, utilities, government, cash ——
    4814: SpendingCategory.bills, // Telecom loads (Jazz, Telenor, Zong, Ufone)
    4900: SpendingCategory.bills, // Utilities (K-Electric, LESCO, SNGPL)
    9399: SpendingCategory.bills, // Government (FBR, passport, Excise & Taxation)
    6513: SpendingCategory.bills, // Real estate / rent platforms
    6011: SpendingCategory.other, // ATM cash withdrawal (not a merchant spend)

    // —— Additional ISO codes (global / PayPak) ——
    // Food / grocery / dining.
    5412: SpendingCategory.food,
    5422: SpendingCategory.food,
    5441: SpendingCategory.food,
    5451: SpendingCategory.food,
    5811: SpendingCategory.food,
    5813: SpendingCategory.food,

    // Transport / fuel / transit.
    4111: SpendingCategory.transport,
    4112: SpendingCategory.transport,
    4131: SpendingCategory.transport,
    4411: SpendingCategory.transport,
    4457: SpendingCategory.transport,
    4468: SpendingCategory.transport,
    4582: SpendingCategory.transport,
    4784: SpendingCategory.transport,
    4789: SpendingCategory.transport,
    5013: SpendingCategory.transport,
    5511: SpendingCategory.transport,
    5521: SpendingCategory.transport,
    5532: SpendingCategory.transport,
    5533: SpendingCategory.transport,
    5542: SpendingCategory.transport, // Automated fuel dispensers
    5551: SpendingCategory.transport,
    5561: SpendingCategory.transport,
    5571: SpendingCategory.transport,
    5599: SpendingCategory.transport,
    7512: SpendingCategory.transport,
    7513: SpendingCategory.transport,
    7519: SpendingCategory.transport,
    7523: SpendingCategory.transport,
    7531: SpendingCategory.transport,
    7534: SpendingCategory.transport,
    7535: SpendingCategory.transport,
    7538: SpendingCategory.transport,
    7542: SpendingCategory.transport,
    7549: SpendingCategory.transport,
    9222: SpendingCategory.transport, // Fines (traffic challan)

    // Pharmacy / health.
    5122: SpendingCategory.pharmacy,
    8011: SpendingCategory.health,
    8021: SpendingCategory.health,
    8031: SpendingCategory.health,
    8041: SpendingCategory.health,
    8042: SpendingCategory.health,
    8043: SpendingCategory.health,
    8049: SpendingCategory.health,
    8050: SpendingCategory.health,
    8062: SpendingCategory.health,
    8071: SpendingCategory.health,
    8099: SpendingCategory.health,
    7298: SpendingCategory.health,

    // Clothing / shoes.
    5611: SpendingCategory.clothing,
    5631: SpendingCategory.clothing,
    5641: SpendingCategory.clothing,
    5655: SpendingCategory.clothing,
    5697: SpendingCategory.clothing,
    5698: SpendingCategory.clothing,
    5699: SpendingCategory.clothing,
    5948: SpendingCategory.clothing,
    5661: SpendingCategory.shoes,

    // Entertainment / digital media.
    5815: SpendingCategory.entertainment,
    5816: SpendingCategory.entertainment,
    5817: SpendingCategory.entertainment,
    5818: SpendingCategory.entertainment,
    7829: SpendingCategory.entertainment,
    7832: SpendingCategory.entertainment,
    7841: SpendingCategory.entertainment,
    7911: SpendingCategory.entertainment,
    7922: SpendingCategory.entertainment,
    7929: SpendingCategory.entertainment,
    7932: SpendingCategory.entertainment,
    7933: SpendingCategory.entertainment,
    7941: SpendingCategory.entertainment,
    7991: SpendingCategory.entertainment,
    7992: SpendingCategory.entertainment,
    7993: SpendingCategory.entertainment,
    7994: SpendingCategory.entertainment,
    7996: SpendingCategory.entertainment,
    7997: SpendingCategory.entertainment,
    7998: SpendingCategory.entertainment,
    7999: SpendingCategory.entertainment,
    4899: SpendingCategory.entertainment,

    // Shopping / general merchandise.
    5200: SpendingCategory.shopping,
    5211: SpendingCategory.shopping,
    5231: SpendingCategory.shopping,
    5251: SpendingCategory.shopping,
    5261: SpendingCategory.shopping,
    5300: SpendingCategory.shopping,
    5309: SpendingCategory.shopping,
    5310: SpendingCategory.shopping,
    5331: SpendingCategory.shopping,
    5399: SpendingCategory.shopping,
    5712: SpendingCategory.shopping,
    5719: SpendingCategory.shopping,
    5722: SpendingCategory.shopping,
    5732: SpendingCategory.shopping,
    5733: SpendingCategory.shopping,
    5734: SpendingCategory.shopping,
    5735: SpendingCategory.shopping,
    5941: SpendingCategory.shopping,
    5942: SpendingCategory.shopping,
    5943: SpendingCategory.shopping,
    5944: SpendingCategory.shopping,
    5945: SpendingCategory.shopping,
    5946: SpendingCategory.shopping,
    5947: SpendingCategory.shopping,
    5970: SpendingCategory.shopping,
    5971: SpendingCategory.shopping,
    5977: SpendingCategory.shopping,
    5999: SpendingCategory.shopping,

    // Bills / telecom.
    4812: SpendingCategory.bills,
    4816: SpendingCategory.bills,
  };

  /// Broad ISO ranges for codes not listed in [_exact].
  /// Exact entries always win (fuel, pharmacy, shoes, PK airlines, hotels, …).
  static const _ranges = <(int, int, SpendingCategory)>[
    (3000, 3299, SpendingCategory.transport), // Airline-specific MCCs
    (5000, 5599, SpendingCategory.shopping),
    (5600, 5699, SpendingCategory.clothing),
    (5700, 5799, SpendingCategory.shopping),
    (5800, 5899, SpendingCategory.food),
    (5900, 5999, SpendingCategory.shopping),
    (7000, 7299, SpendingCategory.other), // lodging overridden by 7011 exact
    (7300, 7529, SpendingCategory.transport),
    (7800, 7999, SpendingCategory.entertainment),
    (8000, 8099, SpendingCategory.health),
    (9300, 9399, SpendingCategory.bills), // government services band
  ];
}
