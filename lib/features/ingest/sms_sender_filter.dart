/// Pure SMS-sender checks shared by [IngestBridge] and unit tests.
///
/// Personal PK mobiles (03… / +923…) are never trusted as wallet alerts;
/// only short codes (4–6 digits) or non-mobile alphanumeric senders pass.
class SmsSenderFilter {
  SmsSenderFilter._();

  /// Digits-only form: strip spaces, dashes, and a leading +92 / 92 country code.
  static String normalize(String sender) {
    var compact = sender.replaceAll(RegExp(r'[\s\-().]'), '');
    if (compact.startsWith('+')) compact = compact.substring(1);
    if (compact.startsWith('92') && compact.length > 6) {
      compact = compact.substring(2);
    }
    // Local mobiles often stored without leading 0 after stripping 92
    // (+92305… → 305…). Treat 10-digit 3XXXXXXXXX as 03XXXXXXXXX.
    if (RegExp(r'^3\d{9}$').hasMatch(compact)) {
      compact = '0$compact';
    }
    return compact;
  }

  /// True for Pakistani personal mobiles (11-digit 03…), not short codes.
  static bool isPersonalMobile(String? sender) {
    if (sender == null || sender.trim().isEmpty) return false;
    final norm = normalize(sender);
    return RegExp(r'^03\d{9}$').hasMatch(norm);
  }

  /// True for 4–6 digit wallet/bank short codes (3737, 8558, …).
  static bool isNumericShortCode(String? sender) {
    if (sender == null || sender.trim().isEmpty) return false;
    final norm = normalize(sender);
    return RegExp(r'^\d{4,6}$').hasMatch(norm);
  }

  /// Whether an SMS event with this originating address may be ingested.
  ///
  /// Rejects personal mobiles. Accepts numeric short codes. Empty/unknown
  /// alphanumeric senders are allowed (native already gated most cases).
  static bool shouldAcceptSmsSender(String? sender) {
    if (sender == null || sender.trim().isEmpty) return true;
    if (isPersonalMobile(sender)) return false;
    return true;
  }
}
