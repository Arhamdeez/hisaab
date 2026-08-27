/// Maps legal / parent-company names from SMS to the brand people recognize.
abstract final class MerchantBrands {
  /// EasyPaisa prints Delivery Hero's legal name; that's Foodpanda in Pakistan.
  static const foodpanda = 'Foodpanda';

  static String displayName(String merchant) {
    final key = _key(merchant);
    if (key.isEmpty) return merchant;
    if (key.contains('delivery hero') ||
        key.contains('deliveryhero') ||
        key == 'foodpanda' ||
        key == 'food panda') {
      return foodpanda;
    }
    return merchant;
  }

  static bool sameBrand(String a, String b) {
    final da = displayName(a);
    final db = displayName(b);
    if (da != a || db != b) {
      return da.toLowerCase() == db.toLowerCase();
    }
    return false;
  }

  static String _key(String merchant) {
    var n = merchant.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    n = n.replaceAll(
      RegExp(
        r'\b(?:pvt|private)\s+ltd\b|\b(?:ltd|limited|llc|inc)\b',
      ),
      ' ',
    );
    return n.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
