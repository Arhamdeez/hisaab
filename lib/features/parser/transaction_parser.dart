import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../models/transaction.dart';
import '../ingest/monitored_packages.dart';
import 'category_guesser.dart';

class ParserRule {
  const ParserRule({
    required this.id,
    required this.name,
    required this.pattern,
    this.sourceHint,
    required this.enabled,
  });

  final int id;
  final String name;
  final String pattern;
  final String? sourceHint;
  final bool enabled;
}

class ParsedTransaction {
  const ParsedTransaction({
    required this.amount,
    required this.type,
    required this.merchant,
    required this.category,
    required this.confidence,
    this.accountRef,
    this.referenceId,
    this.occurredAt,
    this.senderName,
    this.receiverName,
    this.isFailed = false,
  });

  final double amount;
  final TransactionType type;
  final String merchant;
  final SpendingCategory category;
  final double confidence;
  final String? accountRef;

  /// Unique transaction/reference number (e.g. "Trx ID 51830190523"). The same
  /// payment shares this across channels; distinct payments never collide.
  final String? referenceId;

  final DateTime? occurredAt;

  /// Counterparty sending money (credit alerts). May be null when unknown.
  final String? senderName;

  /// Counterparty receiving money (debit alerts). May be null when unknown.
  final String? receiverName;

  /// Bank/wallet alert for a declined or blocked payment — not real spending.
  final bool isFailed;
}

class TransactionParser {
  TransactionParser({List<ParserRule>? rules})
      : _rules = List.of(rules ?? defaultRules);

  final List<ParserRule> _rules;

  static const confidenceThreshold = 0.75;

  static final defaultRules = <ParserRule>[
    ParserRule(
      id: 1,
      name: 'HDFC Debit',
      pattern:
          r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)\s+(?:debited|spent|paid)',
      sourceHint: 'sms',
      enabled: true,
    ),
    ParserRule(
      id: 2,
      name: 'UPI Payment',
      pattern:
          r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?).*?(?:to|at|for)\s+([A-Za-z0-9 &.\-]+)',
      sourceHint: 'notification',
      enabled: true,
    ),
    ParserRule(
      id: 3,
      name: 'Credit Received',
      pattern:
          r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)\s+(?:credited|received|deposited)',
      sourceHint: 'sms',
      enabled: true,
    ),
    ParserRule(
      id: 4,
      name: 'GPay',
      pattern:
          r'(?:paid|sent)\s+(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)\s+(?:to|for)\s+([A-Za-z0-9 &.\-]+)',
      sourceHint: 'notification',
      enabled: true,
    ),
    ParserRule(
      id: 5,
      name: 'Paytm',
      pattern:
          r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)\s+(?:spent|paid|debited)',
      sourceHint: 'gmail',
      enabled: true,
    ),
    ParserRule(
      id: 6,
      name: 'PhonePe',
      pattern:
          r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)\s+(?:paid|sent|debited)',
      sourceHint: 'notification',
      enabled: true,
    ),
    ParserRule(
      id: 7,
      name: 'ICICI Debit',
      pattern:
          r'(?:debited|spent).*?(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)',
      sourceHint: 'sms',
      enabled: true,
    ),
    ParserRule(
      id: 8,
      name: 'SBI Alert',
      pattern:
          r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?).*?(?:debited|withdrawn)',
      sourceHint: 'sms',
      enabled: true,
    ),
    ParserRule(
      id: 9,
      name: 'Generic Debit',
      pattern:
          r'(?:debited|spent|paid|withdrawn).*?(?:Rs\.?|PKR|INR|₹|₨)\s*([\d,]+(?:\.\d+)?)',
      enabled: true,
    ),
    ParserRule(
      id: 10,
      name: 'Generic Credit',
      pattern:
          r'(?:credited|received|deposited).*?(?:Rs\.?|PKR|INR|₹|₨)\s*([\d,]+(?:\.\d+)?)',
      enabled: true,
    ),
    ParserRule(
      id: 11,
      name: 'UBL / PKR Debit',
      pattern:
          r'(?:PKR|Rs\.?)\s*([\d,]+(?:\.\d+)?).*?(?:debited|debit|deducted|withdrawn|spent|paid)',
      sourceHint: 'notification',
      enabled: true,
    ),
    ParserRule(
      id: 12,
      name: 'UBL / PKR Credit',
      pattern:
          r'(?:PKR|Rs\.?)\s*([\d,]+(?:\.\d+)?).*?(?:credited|credit|deposited|received)',
      sourceHint: 'notification',
      enabled: true,
    ),
    ParserRule(
      id: 13,
      name: 'PKR Debit (amount after verb)',
      pattern:
          r'(?:debited|deducted|withdrawn).*?(?:PKR|Rs\.?)\s*([\d,]+(?:\.\d+)?)',
      enabled: true,
    ),
    ParserRule(
      id: 14,
      name: 'JazzCash Sent',
      pattern:
          r'(?:sent|you sent)\s+(?:PKR|Rs\.?)\s*([\d,]+(?:\.\d+)?).*?(?:to|via)',
      sourceHint: 'notification',
      enabled: true,
    ),
    ParserRule(
      id: 15,
      name: 'JazzCash / EasyPaisa Received',
      pattern:
          r'(?:PKR|Rs\.?)\s*([\d,]+(?:\.\d+)?).*?(?:received|credited|added)',
      sourceHint: 'notification',
      enabled: true,
    ),
    ParserRule(
      id: 16,
      name: 'Wallet Transfer Successful',
      pattern:
          r'(?:PKR|Rs\.?)\s*([\d,]+(?:\.\d+)?).*?(?:transfer\s*successful|successfully\s*transferred)',
      sourceHint: 'notification',
      enabled: true,
    ),
    ParserRule(
      id: 17,
      name: 'Has been debited/credited',
      pattern:
          r'has\s+been\s+(?:debited|credited|deducted).*?(?:PKR|Rs\.?)\s*([\d,]+(?:\.\d+)?)',
      enabled: true,
    ),
    ParserRule(
      id: 18,
      name: 'PK You sent Rs',
      pattern:
          r'you\s+sent\s+(?:PKR|Rs\.?|INR|₹|₨)\.?\s*([\d,]+(?:\.\d+)?)',
      sourceHint: 'notification',
      enabled: true,
    ),
    ParserRule(
      id: 19,
      name: 'PK You received Rs',
      pattern:
          r'you\s+(?:have\s+)?(?:received|got)\s+(?:PKR|Rs\.?|INR|₹|₨)\.?\s*([\d,]+(?:\.\d+)?)',
      sourceHint: 'notification',
      enabled: true,
    ),
    ParserRule(
      id: 20,
      name: 'PK Amount of Rs sent',
      pattern:
          r'(?:an\s+)?amount\s+of\s+(?:PKR|Rs\.?)\.?\s*([\d,]+(?:\.\d+)?).*?(?:successfully\s+)?sent',
      sourceHint: 'notification',
      enabled: true,
    ),
    ParserRule(
      id: 21,
      name: 'Raast Money Transfer of Rs',
      pattern:
          r'money\s+transfer\s+of\s+(?:PKR|Rs\.?)\.?\s*([\d,]+(?:\.\d+)?)',
      sourceHint: 'notification',
      enabled: true,
    ),
    ParserRule(
      id: 22,
      name: 'Payment/transfer of amount',
      pattern:
          r'(?:payment|transfer|transaction|remittance|payout)\s+of\s+'
          r'(?:PKR|Rs\.?|INR|₹|₨|\$|€|£|USD|EUR|GBP)\.?\s*([\d,]+(?:\.\d+)?)',
      sourceHint: 'notification',
      enabled: true,
    ),
    ParserRule(
      id: 23,
      name: 'Amount has been debited/credited',
      pattern:
          r'(?:PKR|Rs\.?|INR|₹|₨)\.?\s*([\d,]+(?:\.\d+)?)\s+has\s+been\s+'
          r'(?:sent|debited|credited|deducted|withdrawn|paid|transferred|received)',
      enabled: true,
    ),
    ParserRule(
      id: 24,
      name: 'Amount was sent/paid',
      pattern:
          r'(?:PKR|Rs\.?|INR|₹|₨)\.?\s*([\d,]+(?:\.\d+)?)\s+was\s+'
          r'(?:successfully\s+)?(?:sent|paid|transferred|debited|credited|received|processed)',
      enabled: true,
    ),
    ParserRule(
      id: 25,
      name: 'You paid/transferred amount',
      pattern:
          r'you\s+(?:have\s+)?(?:paid|transferred|spent|withdrew)\s+'
          r'(?:PKR|Rs\.?|INR|₹|₨)\.?\s*([\d,]+(?:\.\d+)?)',
      sourceHint: 'notification',
      enabled: true,
    ),
    ParserRule(
      id: 26,
      name: 'UPI/IMPS/Raast rails',
      pattern:
          r'(?:PKR|Rs\.?|INR|₹|₨|\$|€|£)\.?\s*([\d,]+(?:\.\d+)?).*?'
          r'\b(?:upi|imps|neft|rtgs|ibft|1link|raast|p2p)\b',
      sourceHint: 'notification',
      enabled: true,
    ),
    ParserRule(
      id: 27,
      name: 'Paid to counterparty',
      pattern:
          r'(?:paid|sent|transferred)\s+(?:PKR|Rs\.?|INR|₹|₨)\.?\s*([\d,]+(?:\.\d+)?)\s+(?:to|for)\s+',
      sourceHint: 'notification',
      enabled: true,
    ),
    ParserRule(
      id: 28,
      name: 'Received from counterparty',
      pattern:
          r'(?:received|credited)\s+(?:PKR|Rs\.?|INR|₹|₨)\.?\s*([\d,]+(?:\.\d+)?)\s+from\s+',
      sourceHint: 'notification',
      enabled: true,
    ),
    ParserRule(
      id: 29,
      name: 'Rs amount sent to counterparty',
      pattern:
          r'(?:PKR|Rs\.?|INR|₹|₨)\.?\s*([\d,]+(?:\.\d+)?)\s+sent\s+to\s+',
      sourceHint: 'notification',
      enabled: true,
    ),
  ];

  void updateRules(List<ParserRule> rules) {
    _rules
      ..clear()
      ..addAll(rules);
  }

  /// Merges title + body — UBL/JazzCash often put PKR amount in the title only.
  static String normalizeIngestText(
    String text, {
    String? notificationTitle,
  }) {
    final body = sanitizeIngestText(text).replaceAll('\n', ' ').trim();
    final title =
        sanitizeIngestText(notificationTitle ?? '').replaceAll('\n', ' ').trim();
    if (title.isEmpty) return body;
    if (body.isEmpty) return title;
    if (body.toLowerCase().contains(title.toLowerCase())) return body;
    return '$title — $body';
  }

  /// Drops Java/FCM metadata and other non-human notification segments.
  static String sanitizeIngestText(String text) {
    if (text.trim().isEmpty) return '';
    final protectedDates = <String>[];
    var scratch = text;
    for (final pattern in _dateProtectPatterns) {
      scratch = scratch.replaceAllMapped(pattern, (match) {
        final token = '@@D${protectedDates.length}@@';
        protectedDates.add(match.group(0)!);
        return token;
      });
    }
    final segments = scratch.split(RegExp(r'\s*[—\-|]\s*'));
    final kept = <String>[];
    for (final segment in segments) {
      final t = segment.trim();
      if (t.isEmpty) continue;
      if (_metadataSegmentPattern.hasMatch(t)) continue;
      kept.add(t);
    }
    var result = kept.join(' — ');
    for (var i = 0; i < protectedDates.length; i++) {
      result = result.replaceAll('@@D$i@@', protectedDates[i]);
    }
    return result;
  }

  static final _dateProtectPatterns = [
    RegExp(r'\b\d{4}-\d{2}-\d{2}\b'),
    RegExp(r'\b\d{2}-[A-Za-z]{3}-\d{4}\b'),
    // Numeric PK bank dates — otherwise sanitize splits "15/07/26" / "16-06-26".
    RegExp(r'\b\d{1,2}[-/]\d{1,2}[-/]\d{2,4}\b'),
  ];

  static final _metadataSegmentPattern = RegExp(
    r'(?:android\.(?:app|x)\.|androidx\.|Notification\$|NotificationCompat|'
    r'FCM-Notification|BigTextStyle|MessagingStyle|InboxStyle|'
    r'^com\.[a-z0-9_.]+\s*$)',
    caseSensitive: false,
  );

  /// Bank/wallet alerts for declined, blocked, or penalized payments — captured
  /// for history but never counted as spending.
  static final _failedTransactionPattern = RegExp(
    r'\b(?:online\s+)?(?:transaction|payment|transfer|purchase|txn)\s+failed\b|'
    r'\bfailed\s+(?:online\s+)?(?:transaction|payment|transfer|purchase)\b|'
    r'\b(?:transaction|payment|transfer|purchase)\s+(?:was\s+)?'
    r'(?:declined|rejected|unsuccessful|not\s+(?:processed|completed))\b|'
    r'\bunsuccessful\s+(?:transaction|payment|transfer|purchase)\b|'
    r'\bcould\s+not\s+(?:be\s+)?(?:processed|completed)\b|'
    r'\bfailed\s+(?:int(?:ernational)?\.?\s+)?transaction(?:s)?\s+fees?\b|'
    r'\b(?:incurred|charged)\s+failed\s+(?:int(?:ernational)?\.?\s+)?'
    r'(?:transaction\s+)?fees?\b',
    caseSensitive: false,
  );

  static final _failedAtMerchantPattern = RegExp(
    r'(?:online\s+)?(?:transaction|payment|purchase)\s+at\s+(.+?)\s+failed\b',
    caseSensitive: false,
  );

  static final _failedFeeAmountPattern = RegExp(
    r'failed\s+(?:int(?:ernational)?\.?\s+)?transaction(?:s)?\s+fees?\s+of\s+'
    r'(?:PKR|Rs\.?)\.?\s*([\d,]+(?:\.\d+)?)',
    caseSensitive: false,
  );

  static final _incurredFailedFeeAmountPattern = RegExp(
    r'(?:incurred|charged)\s+failed\s+(?:int(?:ernational)?\.?\s+)?'
    r'(?:transaction\s+)?fees?\s+of\s+(?:PKR|Rs\.?)\.?\s*([\d,]+(?:\.\d+)?)',
    caseSensitive: false,
  );

  /// Returns true when [text] is a declined/blocked payment alert, not a real
  /// debit or credit.
  static bool isFailedTransactionNotification(String text) =>
      _failedTransactionPattern.hasMatch(text);

  /// Fingerprint for failed alerts — includes raw text so repeated failures at
  /// the same merchant on the same day stay distinct.
  static String buildFailedFingerprint({
    required DateTime occurredAt,
    required String merchant,
    required String rawText,
    String? referenceId,
  }) {
    if (referenceId != null && referenceId.isNotEmpty) {
      final payload = 'failed|ref:$referenceId';
      return sha256.convert(utf8.encode(payload)).toString();
    }
    final day = '${occurredAt.year}-${occurredAt.month}-${occurredAt.day}';
    final cleaned = merchant.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final normalizedMerchant =
        cleaned.length > 24 ? cleaned.substring(0, 24) : cleaned;
    final textKey = sha256.convert(utf8.encode(rawText.trim())).toString();
    final payload = 'failed|$day|$normalizedMerchant|$textKey';
    return sha256.convert(utf8.encode(payload)).toString();
  }

  /// Non-finance alerts that often contain numbers — never treat as cash.
  static final _noiseNotificationPattern = RegExp(
    r'\b(?:otp|one[\s-]?time\s+(?:password|pin|code)|verification\s+code|'
    r'confirm(?:ation)?\s+code|security\s+code|passcode)\b|'
    r'\b(?:followers?|following|subscribers?|views?|likes?)\b|'
    r'\b(?:steps|calories|heart\s+rate|km\s+walked|workout)\b|'
    r'\b(?:battery|charging|charge\s+complete)\b|'
    r'\b(?:update\s+available|new\s+version|downloading|install(?:ing|ed)|updating|'
    r'update\s+(?:in\s+progress|complete|failed|ready)|finishing\s+update)\b|'
    r'\b(?:whatsapp\s+update|backup(?:ping)?|backup\s+in\s+progress|restoring\s+messages|'
    r'chat\s+backup|uploading\s*:|download(?:ing)?\s*:)\b|'
    r'\b(?:out\s+for\s+delivery|order\s+confirmed|your\s+order\s+#|track(?:ing)?\s+(?:your|order))\b|'
    r'\b(?:flash\s+sale|limited\s+offer|promo\s+code|coupon|\d+\s*%\s*off)\b|'
    r'\b\d+\s*%\s*cashback\b|'
    r'\bget\s+upto\b|\bupto\s+[\d,]+(?:\s+cashback)?\b|'
    r'\bcashback\s+on\b|'
    r'\bjoin\s+karein\b|\bmein\s+join\b|'
    r'\beligible\s+hain\b|'
    r'\brewards?\s+(?:ke\s+liye|aap\s+ka\s+intezar)\b|'
    r'\bintezar\s+kar\s+rahe\b|'
    r'\b(?:missed\s+call|incoming\s+call|voice\s+mail)\b|'
    r'\b(?:weather|forecast|rain\s+alert)\b|'
    r'\b(?:match\s+score|full\s+time)\b|'
    r'\b(?:get\s+a\s+chance|chance\s+to\s+(?:win|earn)|for\s+a\s+chance|'
    r'win\s+(?:\d+|a\s+|1\s)|'
    r'(?:\d+\s+)?crore|(?:\d+\s+)?lakh|(?:\d+\s+)?lac)\b|'
    // Bank/card spend-and-win promos (English + Roman Urdu).
    r'\bwin\s+big\b|'
    r'\bt\s*&\s*cs?\s+apply\b|\bterms\s+(?:and|&)\s+conditions\s+apply\b|'
    r'\bjeet(?:ne|ein|o)\b|\bmauqa\s+hasil\b|\bka\s+mauqa\b|'
    r'\b(?:spend|shopping|istemal|use)\s+karein\b|'
    r'\bspend\s+globally\b|'
    r'\boffer\s+valid\b|\bvalid\s+(?:till|until)\b|'
    r'\bmaintain\s+(?:rs\.?|pkr)\b|'
    r'\b(?:refer(?:ral)?|invite\s+(?:friends?|and\s+earn))\b|'
    r'\b\d+\s*(?:mb|gb|kb|tb)\s+of\s+\d+\s*(?:mb|gb|kb|tb)\b|'
    // Crypto / token marketing pushes that mention \$ amounts.
    r'\bbuy\s+any\s+amount\b|'
    r'\bfor\s+a\s+chance\s+to\s+earn\b|'
    r'\bearn\s+\$\s*[\d,]+|'
    r'\bturn\s+your\b.{0,40}\binto\s+more\b|'
    // Platform payout notices — not local wallet/bank alerts.
    r'\bupwork\b|'
    r'withdrawal\s+of\s+your\s+upwork\s+balance|'
    r'amount\s+you\s+should\s+receive\b|'
    // Campus / university announcements — not payments.
    r'international\s+(?:education\s+)?office\b|'
    r'three\s+global\s+opportunities\b|'
    r'semester\s+exchange\b|'
    r'gebze\s+technical\s+university\b|'
    r'fast\s*[—–\-]\s*nuc(?:es)?\b|'
    r'(?:tuition\s*zero|zero\s+tuition)\b|'
    r'\bcgpa\s*[≥>=]\s*[\d.]+\b|'
    // Telecom / carrier promos that mention Rs amounts.
    r'\b(?:weekly|monthly|daily)\s+(?:freedom|x\s+plus|package|bundle)\b|'
    r'\b(?:simosa|full\s+balance\s+offer|jazz\s*advance|readycash|jazztune|jazz\s*caller)\b|'
    r'\b(?:subscribe\s+now|dial\s*\*|code\s*\*|bit\.ly/|onelink\.to/)\b|'
    r'\b(?:\d+\s*)?(?:gb|mb)\s*,\s*\d+\s+(?:other\s+)?(?:network\s+)?min|' +
    // Bank / wallet service maintenance — not payments.
    r'\b(?:maintenance|scheduled\s+maintenance|system\s+maintenance|planned\s+maintenance)\b|' +
    r'\b(?:services?\s+will\s+be\s+unavailable|temporarily\s+unavailable)\b|' +
    r'\b(?:service\s+disruptions?|intermittent\s+service)\b|' +
    r'\b(?:downtime|service\s+outage|planned\s+outage)\b|' +
    r'\bunavailable\s+due\s+to\b|' +
    r'\b(?:apologize|apologise)\s+for\s+(?:any\s+)?inconvenience\b|' +
    r'\braast\s+(?:system\s+)?maintenance\b|' +
    r'\bmaintenance\s+(?:window|period|activity)\b|' +
    r'\b(?:for\s+any\s+queries|please\s+(?:immediately\s+)?call)\b|' +
    // Bank login / security — not money movement.
    r'\b(?:login|log[\s-]?in)\s+successful\b|' +
    r'\bsuccessfully\s+logged\s+in\b|' +
    r'\blogged\s+in\s+to\b|' +
    r'\bdo\s+not\s+recogni[sz]e\s+this\s+login\b|' +
    r'\bunrecogni[sz]ed\s+login\b|' +
    r'\bnew\s+device\s+(?:login|sign[\s-]?in)\b|' +
    r'\b(?:security|fraud)\s+alert\b|' +
    r'\bhelpline\b|' +
    r'\bblock\s+(?:the\s+)?(?:mobile\s+)?banking\b',
    caseSensitive: false,
  );

  /// Marketing / promotional wording (English + Roman Urdu). Promos use
  /// future or imperative phrasing — "win", "avail", "spend karein" — while
  /// genuine alerts describe completed money movement. Any app's message
  /// matching this with no completed-transaction evidence is rejected.
  static final _promoSignalPattern = RegExp(
    r'\bwin\b|\bprizes?\b|\blucky\s+draw\b|\bbumper\s+(?:prize|offer|draw)\b|'
    r'\binaam\b|\bjeet(?:ne|ein|ain|o)?\b|\bmauqa\b|\bmuft\b|'
    r'\bdiscounts?\b|\bvouchers?\b|\bpromo\b|\bcoupons?\b|'
    r'\b(?:mega|flash|grand|big)\s+sale\b|\bsale\s+is\s+live\b|'
    r'\b(?:exclusive|special|exciting|amazing)\s+offer\b|'
    r'\boffer\s+(?:valid|ends?|expires?)\b|\bvalid\s+(?:till|until|upto)\b|'
    r'\bavail\s+(?:now|this|the|exciting|amazing|karein)\b|'
    r'\bapply\s+now\b|\bregister\s+(?:now|today)\b|\bsign\s+up\b|'
    r'\bdownload\s+(?:now|the\s+app)\b|'
    r'\bhurry\b|\blimited\s+time\b|\bdon.?t\s+miss\b|\blast\s+chance\b|'
    r'\bstand\s+a\s+chance\b|\bfor\s+a\s+chance\b|'
    r'\bchance\s+to\s+(?:win|earn)\b|'
    r'\bget\s+(?:up\s*to|a\s+free|your\s+free)\b|'
    r'\bearn\s+(?:up\s*to|points|rewards|\$)\b|'
    r'\bbuy\s+any\s+amount\b|'
    r'\bupgrade\s+(?:your|to|now)\b|\bshop\s+(?:now|and\s+win|&\s+win)\b|'
    r'\bfree\s+(?:delivery|gift|voucher|coupon|tickets?|entry)\b|'
    r'\b(?:spend|shopping|istemal|use|recharge|load)\s+kar(?:ein|o|iye)\b|'
    r'\bkarein\s+aur\b|\bhasil\s+kar(?:ein|o|iye)\b|\bkijiye\b|'
    r'\buthayein\b|\bbanayein\b|\bpayein\b|'
    r'\bt\s*&\s*cs?\b|\bterms\s+(?:and|&)\s+conditions\b|'
    r'\bfx\s+fee\b|\bbachat\b|\bfaida\b|\bmoassar\b',
    caseSensitive: false,
  );

  /// Completed money-movement evidence — overrides promo wording so genuine
  /// alerts that happen to mention rewards or offers still parse.
  static final _completedTxnEvidencePattern = RegExp(
    r'has\s+been\s+(?:debited|credited|deducted|withdrawn|transferred|sent|paid|received|reversed)|'
    r'(?:debited|credited|deducted|withdrawn)\s+(?:by|with|from|for)\b|'
    r'\byou\s+(?:have\s+)?(?:sent|paid|received|transferred)\b|'
    r'\bsuccessfully\s+(?:sent|received|transferred|paid|credited|debited)|'
    r'\b(?:transaction|transfer|payment|txn)\s+(?:successful|completed?)\b|'
    r'\b(?:trx|txn|trxn|transaction)\s*(?:id|no|#)|'
    r'\bref(?:erence)?\s*(?:id|no|#|:)|'
    r'\b(?:available|remaining|current|new)\s+balance\b|\bbal(?:ance)?\s*[:=]|'
    r'\breceived\s+from\b|\b(?:paid|sent|transferred)\s+to\b|'
    r'\bpurchase\s+(?:of|at)\b|\b(?:pos|atm)\s+(?:purchase|withdrawal|transaction)\b|'
    r'\bvia\s+(?:raast|ibft|pos|atm|1link)\b|'
    r'\b(?:is\s+)?charged\b.*?\bfor\s+(?:pkr|rs\.?)',
    caseSensitive: false,
  );

  /// Promo wording with no completed-transaction evidence — never cash.
  static bool _isPromotionalContent(String text) =>
      _promoSignalPattern.hasMatch(text) &&
      !_isUniversalTxnTrigger(text) &&
      !_completedTxnEvidencePattern.hasMatch(text);

  /// Strong money-movement wording — required for unknown apps (with currency).
  static final _strongFinanceSignals = RegExp(
    r'debited|credited|withdrawn|deducted|spent|transferred|purchase|'
    r'\bcharged\b|\bis\s+charged\b|'
    r'(?:debited|deducted|withdrawn|credited)\s+by\s+(?:pkr|rs\.?)|'
    r'fund\s+transfer|funds?\s+transfer|transfer\s+to|transfer\s+successful|'
    r'mobile\s+wallet|wallet\s+a/c|'
    r'money\s+(?:received|sent)|payment\s+(?:received|sent)|'
    r'you\s+(?:sent|paid|received|transferred)|'
    r'(?:paid|sent|transferred)\s+to\b|'
    r'(?:paid|sent|transferred)\s+(?:pkr|rs\.?|inr|₹|₨|\$|€|£)|'
    r'(?:payment|transfer|transaction|remittance|payout)\s+of\s+(?:pkr|rs\.?|inr|₹|₨|\$|€|£)|'
    r'amount\s+of\s+(?:pkr|rs\.?)|money\s+transfer\s+of|'
    r'has\s+been\s+(?:debited|credited|sent|paid|transferred|received)|'
    r'(?:pkr|rs\.?|inr|₹|₨)\.?\s*[\d,]+(?:\.\d+)?\s+(?:has\s+been|was)\s+'
    r'(?:debited|credited|sent|paid|transferred|received)|'
    r'successfully\s+sent\s+to|transfer\s*successful|successfully\s*transferred|'
    r'(?:outgoing|incoming)\s+(?:payment|transfer|transaction|money)|'
    r'(?:pkr|rs\.?)\.?\s*[\d,]+(?:\.\d+)?\s+sent\s+to\b|'
    r'(?:pkr|rs\.?)\.?\s*[\d,]+(?:\.\d+)?\s+received\s+from\b|'
    r'(?:pkr|rs\.?)\.?\s*[\d,]+(?:\.\d+)?\s+with\b|'
    r'you\s+(?:have\s+)?paid\s+(?:pkr|rs\.?)\.?\s*[\d,]+(?:\.\d+)?\s+at\b|'
    r'a/c\s*\*+|account\s*\*+|trx\s*id|trans(?:action)?\s*id|'
    r'raast|ibft|1link|\bupi\b|\bimps\b|\bneft\b|\brtgs\b',
    caseSensitive: false,
  );

  static final _monitoredWalletFallback = RegExp(
    r'a/c\s*\*+|account\s*\*+|trx\s*id|trans(?:action)?\s*id|t(?:xn|rxn)\s*no|'
    r'\bTID:\s*\d{5,}',
    caseSensitive: false,
  );

  // Signals real money movement — aligned with Android IngestPlugin.walletTxnRegex.
  static final _walletTxnSignals = RegExp(
    r'debited|credited|spent|withdrawn|deducted|transferred|received|'
    r'\bpaid\b|\bsent\b|purchase|\btxn\b|transaction|\bdebit\b|\bcredit\b|'
    r'refund|(?:received|credited|you\s+(?:have\s+)?got).{0,50}cashback|'
    r'cashback.{0,50}(?:received|credited|in\s+your)|deposited|salary|transfer|withdrawal|'
    r'payment|charged|\bbill\b|added|successful|completed|processed|'
    r'money\s+received|money\s+sent|payment\s+received|payment\s+sent|'
    r'transfer\s*successful|successfully\s*transferred|'
    r'you\s+sent|you\s+paid|you\s+transferred|sent\s+to|paid\s+to|transfer\s+to|transfer\s+from|'
    r'received\s+from|amount\s+of\s+(?:rs|pkr)|money\s+transfer\s+of|successfully\s+sent|'
    r'(?:payment|transfer|transaction|remittance|payout)\s+of\s+(?:rs|pkr|inr|\$|€|£)|'
    r'outgoing|incoming|remittance|payout|top-?up|cash\s+(?:in|out)|'
    r'raast|ibft|1link|\bupi\b|\bimps\b|\bneft\b|\brtgs\b|\bp2p\b|transaction\s+successful|'
    r'sent\s*(?:rs|pkr)|received\s*(?:rs|pkr)|'
    r'a/c\s*\*+|account\s*\*+|your\s+account|trx\s*id|trans(?:action)?\s*id|t(?:xn|rxn)\s*no|'
    r'has\s*been\s*(?:debited|credited|deducted|sent|paid|transferred|received)|'
    r'was\s+(?:successfully\s+)?(?:sent|paid|transferred|debited|credited|received|processed)',
    caseSensitive: false,
  );

  /// Payment rails — UPI, IMPS, Raast, etc. (amount required elsewhere).
  static final _railsPattern = RegExp(
    r'\b(?:upi|imps|neft|rtgs|ibft|1link|raast|p2p|swift|ach)\b',
    caseSensitive: false,
  );

  static final _successfulTxnPattern = RegExp(
    r'(?:successful|completed|processed)\s+'
    r'(?:payment|transfer|transaction|payout|remittance)',
    caseSensitive: false,
  );

  static final _directionTransferPattern = RegExp(
    r'\b(outgoing|incoming)\s+(?:payment|transfer|transaction|money)\b',
    caseSensitive: false,
  );

  static final _paymentOfPattern = RegExp(
    r'(?:payment|transfer|transaction|remittance|payout)\s+of\s+'
    r'(?:PKR|Rs\.?|INR|₹|₨|\$|€|£|USD|EUR|GBP)\.?\s*([\d,]+(?:\.\d+)?)',
    caseSensitive: false,
  );

  static final _amountHasBeenPattern = RegExp(
    r'(?:PKR|Rs\.?|INR|₹|₨)\.?\s*([\d,]+(?:\.\d+)?)\s+has\s+been\s+'
    r'(sent|debited|credited|deducted|withdrawn|paid|transferred|received)',
    caseSensitive: false,
  );

  static final _amountWasPattern = RegExp(
    r'(?:PKR|Rs\.?|INR|₹|₨)\.?\s*([\d,]+(?:\.\d+)?)\s+was\s+'
    r'(?:successfully\s+)?(sent|paid|transferred|debited|credited|received|processed)',
    caseSensitive: false,
  );

  static final _youPaidPattern = RegExp(
    r'you\s+(?:have\s+)?(?:paid|transferred|spent|withdrew)\s+'
    r'(?:PKR|Rs\.?|INR|₹|₨|\$|€|£)\.?\s*([\d,]+(?:\.\d+)?)',
    caseSensitive: false,
  );

  ParsedTransaction? parse(
    String text, {
    required TransactionSource source,
    DateTime? fallbackTime,
    String? packageName,
    String? notificationTitle,
  }) {
    final normalized = normalizeIngestText(text, notificationTitle: notificationTitle);
    if (normalized.isEmpty) return null;

    if (isFailedTransactionNotification(normalized)) {
      return _parseFailed(
        text: text,
        normalized: normalized,
        source: source,
        fallbackTime: fallbackTime,
        packageName: packageName,
        notificationTitle: notificationTitle,
      );
    }

    if (!_looksLikeTransaction(
      normalized,
      packageName: packageName,
      notificationTitle: notificationTitle,
    )) {
      return null;
    }

    final type = _detectType(
      normalized,
      notificationTitle: notificationTitle,
      packageName: packageName,
    );
    final amount = _extractAmount(
      normalized,
      packageName: packageName,
      notificationTitle: notificationTitle,
    );
    if (amount == null || amount <= 0) return null;

    final parties = _extractTransferParties(normalized, type);
    final merchant = _resolveMerchantName(
          normalized,
          type,
          parties,
          notificationTitle: notificationTitle,
        ) ??
        'Unknown';
    var senderName = parties.$1;
    var receiverName = parties.$2;
    if (type == TransactionType.credit &&
        senderName == null &&
        merchant != 'Unknown') {
      senderName = merchant;
    } else if (type == TransactionType.debit &&
        receiverName == null &&
        merchant != 'Unknown') {
      receiverName = merchant;
    }

    final accountRef = _extractAccountRef(normalized);
    final referenceId = extractReferenceId(text);
    // Read the date from the raw text first: sanitization can still mangle
    // unusual date shapes, so raw wins over the normalized title+body merge.
    final occurredAt = _extractOccurredAt(text, fallbackTime: fallbackTime) ??
        _extractOccurredAt(normalized, fallbackTime: fallbackTime) ??
        fallbackTime;
    final category = CategoryGuesser.guess('$merchant $normalized');

    var confidence = 0.55;
    for (final rule in _rules) {
      if (!rule.enabled) continue;
      if (rule.sourceHint != null && rule.sourceHint != source.storageKey) {
        continue;
      }
      final regex = RegExp(rule.pattern, caseSensitive: false);
      if (regex.hasMatch(normalized)) confidence += 0.12;
    }
    if (merchant != 'Unknown') confidence += 0.1;
    if (accountRef != null) confidence += 0.08;
    if (occurredAt != null) confidence += 0.05;
    if (_youSentRsPattern.hasMatch(normalized) ||
        _youReceivedRsPattern.hasMatch(normalized) ||
        _amountOfRsPattern.hasMatch(normalized) ||
        _moneyTransferOfRsPattern.hasMatch(normalized) ||
        _isUniversalTxnTrigger(normalized)) {
      confidence += 0.15;
    }
    if (_isAmbiguousDirection(normalized, notificationTitle, packageName)) {
      confidence = (confidence - 0.2).clamp(0.0, 1.0);
    }
    confidence = confidence.clamp(0.0, 1.0);

    return ParsedTransaction(
      amount: amount,
      type: type,
      merchant: merchant,
      category: category,
      confidence: confidence,
      accountRef: accountRef,
      referenceId: referenceId,
      occurredAt: occurredAt,
      senderName: senderName,
      receiverName: receiverName,
    );
  }

  ParsedTransaction? _parseFailed({
    required String text,
    required String normalized,
    required TransactionSource source,
    DateTime? fallbackTime,
    String? packageName,
    String? notificationTitle,
  }) {
    if (MonitoredPackages.isExcluded(packageName)) return null;
    if (_isNoiseNotification(normalized)) return null;

    final hasPackage = packageName != null && packageName.isNotEmpty;
    final isFinanceApp = MonitoredPackages.matches(packageName);
    final isEmail = MonitoredPackages.isEmailClient(packageName);
    if (hasPackage && !isFinanceApp && !isEmail) return null;

    final amount = _extractFailedTransactionAmount(normalized) ?? 0;
    final merchant = _extractFailedMerchant(normalized, notificationTitle);
    final accountRef = _extractAccountRef(normalized);
    final referenceId = extractReferenceId(text);
    final occurredAt = _extractOccurredAt(text, fallbackTime: fallbackTime) ??
        _extractOccurredAt(normalized, fallbackTime: fallbackTime) ??
        fallbackTime;
    final category = CategoryGuesser.guess('$merchant $normalized');

    return ParsedTransaction(
      amount: amount,
      type: TransactionType.debit,
      merchant: merchant,
      category: category,
      confidence: 0.92,
      accountRef: accountRef,
      referenceId: referenceId,
      occurredAt: occurredAt,
      isFailed: true,
    );
  }

  static double? _extractFailedTransactionAmount(String text) {
    for (final pattern in [
      _incurredFailedFeeAmountPattern,
      _failedFeeAmountPattern,
    ]) {
      final amount = _amountFromPattern(pattern, text);
      if (amount != null && amount > 0) return amount;
    }
    return _amountFromCurrencyLabel(text);
  }

  String _extractFailedMerchant(String text, String? notificationTitle) {
    final atMerchant = _failedAtMerchantPattern.firstMatch(text);
    if (atMerchant != null) {
      final name = _trimMerchant(atMerchant.group(1)!.trim());
      if (_isUsableMerchant(name)) return name;
    }

    if (_failedFeeAmountPattern.hasMatch(text) ||
        _incurredFailedFeeAmountPattern.hasMatch(text)) {
      return 'Failed transaction fee';
    }

    final fromTitle = _extractMerchantFromTitle(notificationTitle);
    if (_isUsableMerchant(fromTitle)) return fromTitle!;

    if (RegExp(r'\bonline\s+transaction\s+failed\b', caseSensitive: false)
        .hasMatch(text)) {
      return 'Online transaction';
    }

    return 'Failed transaction';
  }

  /// Pulls a transaction/reference number out of an alert. The same payment
  /// carries the same id across the wallet app, email, and bank SMS, so it is
  /// the strongest signal that two alerts describe one payment — and, just as
  /// importantly, that two same-amount alerts are *different* payments.
  static String? extractReferenceId(String text) {
    final match = RegExp(
      r'(?:trx|txn|trxn|trans(?:action)?|tid|ref(?:erence)?(?:\s*(?:no|id|#))?|'
      r'rrn|stan|auth(?:orization)?\s*(?:code|id)?)'
      r'\s*(?:id|no|number|#|:)?\s*[:#-]?\s*([a-z0-9]{5,})',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;
    final raw = match.group(1)!;
    // Ignore masked account fragments like "****1541" matched as a ref.
    if (RegExp(r'^[*x]+\d*$', caseSensitive: false).hasMatch(raw)) return null;
    return raw.toLowerCase();
  }

  static const _partyCapture =
      r"([A-Za-z\u0600-\u06FF][A-Za-z0-9\u0600-\u06FF .'\-&]{0,48})";
  static const _partyCaptureLazy =
      r"([A-Za-z\u0600-\u06FF][A-Za-z0-9\u0600-\u06FF .'\-&]{0,48}?)";

  static final _genericMerchants = RegExp(
    r'^(?:unknown|dear customer|customer|wallet|account|payment|money|'
    r'jazzcash|easypaisa|mobilink|sadapay|nayapay|ubl|hbl|mcb|'
    r'transaction alert|money received|money sent|payment received|'
    r'transfer successful|successful transfer|transfer)$',
    caseSensitive: false,
  );

  String? _resolveMerchantName(
    String text,
    TransactionType type,
    (String?, String?) parties, {
    String? notificationTitle,
  }) {
    // Body counterparty always wins over notification headings
    // ("Raast Incoming Payment", "Meezan Bank Alert", etc.).
    if (type == TransactionType.credit) {
      final sender = parties.$1;
      if (_isUsablePartyName(sender)) return sender;

      for (final pattern in _creditSenderPatterns) {
        final match = pattern.firstMatch(text);
        if (match == null) continue;
        final name = _trimMerchant(match.group(1)!.trim());
        if (_isUsablePartyName(name)) return name;
      }
    } else {
      final receiver = parties.$2;
      if (_isUsablePartyName(receiver)) return receiver;
    }

    final extracted = _extractMerchant(text, type: type);
    if (_isUsablePartyName(extracted)) return extracted;

    // Title is a last resort — only real person/merchant names, never alert headings.
    final fromTitle = _extractMerchantFromTitle(notificationTitle);
    if (_isPersonNameTitle(notificationTitle) && _isUsablePartyName(fromTitle)) {
      return fromTitle;
    }
    if (_isUsablePartyName(fromTitle) &&
        !_isAlertStyleHeading(fromTitle!) &&
        !_isPhoneLike(fromTitle) &&
        !_isSmsShortCode(fromTitle)) {
      return fromTitle;
    }
    if (_isUsableMerchant(fromTitle) &&
        !_isAlertStyleHeading(fromTitle!) &&
        !_isPhoneLike(fromTitle) &&
        !_isSmsShortCode(fromTitle)) {
      return fromTitle;
    }
    return extracted;
  }

  /// Wallet/bank SMS short codes (3737, 8558, …) — never a merchant name.
  static bool _isSmsShortCode(String? value) {
    if (value == null) return false;
    return RegExp(r'^\d{3,6}$').hasMatch(value.trim());
  }

  String? _extractMerchantFromTitle(String? title) {
    if (title == null) return null;
    var trimmed = title.trim();
    if (trimmed.isEmpty ||
        _isGenericAlertTitle(trimmed) ||
        _isAmountOrAlertTitle(trimmed) ||
        _isSmsShortCode(trimmed)) {
      return null;
    }

    trimmed = trimmed.replaceAll(
      RegExp(
        r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE00}-\u{FE0F}\u{200D}]+$',
        unicode: true,
      ),
      '',
    ).trim();

    final leading = _nameBeforeSentenceDot(trimmed);
    if (leading != null) return leading;

    if (_isUsableMerchant(trimmed) && !_isPhoneLike(trimmed)) {
      return _trimMerchant(trimmed);
    }
    return null;
  }

  bool _isAmountOrAlertTitle(String value) {
    final v = value.trim();
    if (RegExp(
      r'(?:rs\.?|pkr|inr|₹|₨|usd|eur|gbp|\$|€|£)\s*[\d,]',
      caseSensitive: false,
    ).hasMatch(v)) {
      return true;
    }
    if (RegExp(
      r'[\d,]+(?:\.\d+)?\s*(?:rs\.?|pkr|inr|₹|₨|usd|eur|gbp|\$|€|£)',
      caseSensitive: false,
    ).hasMatch(v)) {
      return true;
    }
    return RegExp(
      r'^(?:you\s+)?(?:have\s+)?(?:received|sent|paid|credited|debited|'
      r'transferred|transfer)\b',
      caseSensitive: false,
    ).hasMatch(v);
  }

  bool _isUsablePartyName(String? value) {
    if (!_isUsableMerchant(value)) return false;
    if (_isPhoneLike(value!)) return false;
    if (_isGenericFromTarget(value)) return false;
    return true;
  }

  static final _genericFromTargets = RegExp(
    r'^(?:your|my|the|a|an|wallet|account|customer|a/c|ac|bank)$',
    caseSensitive: false,
  );

  bool _isGenericFromTarget(String value) {
    final n = value.toLowerCase().trim();
    if (_genericFromTargets.hasMatch(n)) return true;
    return RegExp(r'^(?:your|my)\s+(?:account|wallet|a/c|ac|bank)$')
        .hasMatch(n);
  }

  bool _isGenericAlertTitle(String value) =>
      TransactionParser._isGenericNotificationTitle(value);

  bool _isPhoneLike(String value) {
    final trimmed = value.trim();
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10 || digits.length > 13) return false;
    return RegExp(r'^[\d+\s\-().]+$').hasMatch(trimmed);
  }

  bool _isUsableMerchant(String? value) {
    if (value == null) return false;
    final trimmed = value.trim();
    if (trimmed.length < 2) return false;
    if (_isSmsShortCode(trimmed)) return false;
    return !_genericMerchants.hasMatch(trimmed);
  }

  static final _creditSenderPatterns = [
    RegExp(
      r'(?:have\s+)?(?:received|credited|credit(?:ed)?)\s+(?:'
      r'(?:rs\.?|pkr|inr|₹|₨)\s*[\d,]+(?:\.\d+)?\s+)?'
      r'from\s+' +
          _partyCapture,
      caseSensitive: false,
    ),
    RegExp(
      r'(?:rs\.?|pkr|inr|₹|₨)\s*[\d,]+(?:\.\d+)?\s+'
      r'(?:has been\s+)?(?:received|credited)\s+from\s+' +
          _partyCapture,
      caseSensitive: false,
    ),
    RegExp(
      r'(?:rs\.?|pkr|inr|₹|₨)\s*[\d,]+(?:\.\d+)?\s+from\s+' + _partyCapture,
      caseSensitive: false,
    ),
    RegExp(
      r'money\s+(?:has been\s+)?received\s+from\s+' + _partyCapture,
      caseSensitive: false,
    ),
    RegExp(
      r'from\s+' +
          _partyCapture +
          r'(?:\s+(?:on|via|at|for|dated)\b|\s*[,.]|$)',
      caseSensitive: false,
    ),
  ];

  // Currency tokens — PK/IN plus global wallets (USD, EUR, …).
  static final _currencyUnits =
      r'(?:Rs\.?|PKR|INR|₹|₨|Rupees?|USD|EUR|GBP|AED|SAR|CAD|AUD|\$|€|£)';

  static final _debitedByPattern = RegExp(
    r'(?:debited|deducted|withdrawn|credited)\s+by\s+'
    r'(?:PKR|Rs\.?)\.?\s*([\d,]+(?:\.\d+)?)',
    caseSensitive: false,
  );

  static final _plainAmountPattern = RegExp(
    r'\b([1-9]\d{0,2}(?:,\d{3})+(?:\.\d{1,2})?|[1-9]\d{2,7}(?:\.\d{1,2})?)\b',
  );

  /// NayaPay casual alerts: "Rs. 500 sent to Inayat Hussain."
  static final _rsSentToPattern = RegExp(
    r'(?:PKR|Rs\.?|INR|₹|₨)\.?\s*([\d,]+(?:\.\d+)?)\s+sent\s+to\b',
    caseSensitive: false,
  );

  /// JazzCash Raast: "Rs 100.0 received from MUHAMMAD ARHAM BABAR AC …"
  static final _rsReceivedFromPattern = RegExp(
    r'(?:PKR|Rs\.?|INR|₹|₨)\.?\s*([\d,]+(?:\.\d+)?)\s+received\s+from\b',
    caseSensitive: false,
  );

  /// Google Wallet / tap-to-pay: "PKR330.00 with EP Digital Card …"
  static final _walletCardPaymentPattern = RegExp(
    r'(?:PKR|Rs\.?)\.?\s*([\d,]+(?:\.\d+)?)\s+with\b',
    caseSensitive: false,
  );

  /// EasyPaisa / card SMS: "You have paid Rs. 330.00 at MERCHANT"
  static final _youPaidAtPattern = RegExp(
    r'you\s+(?:have\s+)?paid\s+(?:PKR|Rs\.?)\.?\s*([\d,]+(?:\.\d+)?)\s+at\b',
    caseSensitive: false,
  );

  /// Primary PK wallet alert shape: "You sent Rs. 1,500.00 …" / Raqami "You just sent PKR 1.00 …"
  static final _youSentRsPattern = RegExp(
    r'you\s+(?:just\s+)?sent\s+(?:PKR|Rs\.?|INR|₹|₨)\.?\s*([\d,]+(?:\.\d+)?)',
    caseSensitive: false,
  );

  /// Raqami / wallets: "You just sent PKR 1.00 to ALI IBRAHIM MUHAMMAD"
  static final _youJustSentToPattern = RegExp(
    r'you\s+just\s+sent\s+(?:PKR|Rs\.?|INR|₹|₨)\.?\s*[\d,]+(?:\.\d+)?\s+to\s+' +
        _partyCapture,
    caseSensitive: false,
  );

  /// Easypaisa received: "You have received Rs.1 in your Easypaisa account…"
  static final _receivedInAccountPattern = RegExp(
    r'you\s+(?:have\s+)?received\s+(?:PKR|Rs\.?)\.?\s*([\d,]+(?:\.\d+)?)\s+in\s+your',
    caseSensitive: false,
  );

  /// Mirror for inbound: "You received Rs. 500.00 …"
  static final _youReceivedRsPattern = RegExp(
    r'you\s+(?:have\s+)?(?:received|got)\s+(?:PKR|Rs\.?|INR|₹|₨)\.?\s*([\d,]+(?:\.\d+)?)',
    caseSensitive: false,
  );

  static bool _isAmbiguousDirection(
    String text,
    String? notificationTitle,
    String? packageName,
  ) {
    if (!MonitoredPackages.matches(packageName)) return false;
    final combined = '${notificationTitle ?? ''} $text'.toLowerCase();
    if (_youSentRsPattern.hasMatch(combined) ||
        _youReceivedRsPattern.hasMatch(combined) ||
        _amountOfRsPattern.hasMatch(combined) ||
        _moneyTransferOfRsPattern.hasMatch(combined) ||
        _isUniversalTxnTrigger(combined)) {
      return false;
    }
    if (_walletTxnSignals.hasMatch(combined)) {
      // Has some direction hint — only ambiguous if no clear credit/debit word.
      const clear = [
        'received', 'credited', 'deposited', 'sent', 'paid', 'debited',
        'withdrawn', 'transferred',
      ];
      if (clear.any(combined.contains)) return false;
    }
    return _plainAmountPattern.hasMatch(text) &&
        !RegExp(r'(?:received|credited|sent|paid|debited)', caseSensitive: false)
            .hasMatch(combined);
  }

  /// Easypaisa / Raast: "An amount of Rs. 1000.0 has been successfully sent…"
  static final _amountOfRsPattern = RegExp(
    r'(?:an\s+)?amount\s+of\s+(?:PKR|Rs\.?)\.?\s*([\d,]+(?:\.\d+)?)',
    caseSensitive: false,
  );

  /// Gmail e-statement: "Money Transfer of Rs. 1000.0 … was successful"
  static final _moneyTransferOfRsPattern = RegExp(
    r'money\s+transfer\s+of\s+(?:PKR|Rs\.?)\.?\s*([\d,]+(?:\.\d+)?)',
    caseSensitive: false,
  );

  /// JazzCash: "PKR 1,000.00 has been successfully transferred to …"
  static final _successfullyTransferredPattern = RegExp(
    r'(?:PKR|Rs\.?)\.?\s*[\d,]+(?:\.\d+)?\s+has\s+been\s+successfully\s+transferred',
    caseSensitive: false,
  );

  /// JazzCash / wallets: "You have successfully sent PKR 100.00 to …"
  static final _successfullySentPattern = RegExp(
    r'you\s+have\s+successfully\s+sent\s+(?:PKR|Rs\.?)\.?\s*[\d,]+(?:\.\d+)?',
    caseSensitive: false,
  );

  /// UBL / bank debit-card SMS: "… is charged … for PKR 5,000.00 at MERCHANT"
  static final _cardChargedForPattern = RegExp(
    r'(?:is\s+)?charged\b.*?\bfor\s+(?:PKR|Rs\.?|INR|₹|₨)\.?\s*([\d,]+(?:\.\d+)?)',
    caseSensitive: false,
  );

  static bool _isUniversalTxnTrigger(String text) {
    return _youSentRsPattern.hasMatch(text) ||
        _youJustSentToPattern.hasMatch(text) ||
        _youReceivedRsPattern.hasMatch(text) ||
        _receivedInAccountPattern.hasMatch(text) ||
        _rsSentToPattern.hasMatch(text) ||
        _rsReceivedFromPattern.hasMatch(text) ||
        _walletCardPaymentPattern.hasMatch(text) ||
        _youPaidAtPattern.hasMatch(text) ||
        _amountOfRsPattern.hasMatch(text) ||
        _moneyTransferOfRsPattern.hasMatch(text) ||
        _successfullyTransferredPattern.hasMatch(text) ||
        _successfullySentPattern.hasMatch(text) ||
        _debitedByPattern.hasMatch(text) ||
        _paymentOfPattern.hasMatch(text) ||
        _amountHasBeenPattern.hasMatch(text) ||
        _amountWasPattern.hasMatch(text) ||
        _youPaidPattern.hasMatch(text) ||
        _cardChargedForPattern.hasMatch(text) ||
        (_directionTransferPattern.hasMatch(text) &&
            _amountFromCurrencyLabel(text) != null) ||
        (_successfulTxnPattern.hasMatch(text) &&
            _amountFromCurrencyLabel(text) != null);
  }

  static bool _isHighConfidenceTxn(String text) {
    return _isUniversalTxnTrigger(text);
  }

  static bool _isNoiseNotification(String text) =>
      _noiseNotificationPattern.hasMatch(text) || _isPromotionalContent(text);

  static bool _hasCurrencyLabel(String text) =>
      _amountFromCurrencyLabel(text) != null;

  static bool _looksLikeTransaction(
    String text, {
    String? packageName,
    String? notificationTitle,
  }) {
    if (MonitoredPackages.isExcluded(packageName)) return false;
    if (_isNoiseNotification(text)) return false;

    final isFinanceApp = MonitoredPackages.matches(packageName);
    final isEmail = MonitoredPackages.isEmailClient(packageName);
    final hasPackage = packageName != null && packageName.isNotEmpty;

    // SMS events have no package — native layer already filters senders.
    if (!hasPackage) {
      if (_isHighConfidenceTxn(text)) return true;
      return _hasCurrencyLabel(text) && _strongFinanceSignals.hasMatch(text);
    }

    if (isEmail) {
      if (_isHighConfidenceTxn(text)) return true;
      return _hasCurrencyLabel(text) && _strongFinanceSignals.hasMatch(text);
    }

    if (!isFinanceApp) return false;

    if (_isHighConfidenceTxn(text)) return true;

    if (!_hasFinanceAmount(
      text,
      packageName: packageName,
      notificationTitle: notificationTitle,
    )) {
      return false;
    }
    // JazzCash / NayaPay often post the counterparty as the title and only
    // the amount in the body — e.g. title "Ahmed Khan", body "2,000.00".
    // Require amount-only body so promo titles like "Yeylo" / "Reward Hub" do
    // not bypass filters when the body is marketing copy with embedded amounts.
    if (_isPersonNameTitle(notificationTitle) &&
        _isAmountOnlyBody(text, notificationTitle: notificationTitle)) {
      return true;
    }
    if (_strongFinanceSignals.hasMatch(text)) return true;
    if (_monitoredWalletFallback.hasMatch(text)) return true;
    if (_isTitleWithAmountBody(
      notificationTitle: notificationTitle,
      text: text,
      packageName: packageName,
    )) {
      return true;
    }
    return false;
  }

  /// Merchant/person in title + amount in body (Google Wallet, JazzCash, NayaPay).
  /// Requires real money-movement wording — a bare "$10" / "PKR 100" in marketing
  /// copy is not enough (crypto/wallet promo pushes abuse that hole).
  static bool _isTitleWithAmountBody({
    required String? notificationTitle,
    required String text,
    String? packageName,
  }) {
    final title = notificationTitle?.trim();
    if (title == null || title.isEmpty || title.length < 3) return false;
    if (_isGenericNotificationTitle(title)) return false;
    if (_genericAlertTitlePattern.hasMatch(title)) return false;
    if (_amountOrAlertTitlePattern.hasMatch(title)) return false;
    if (!_hasFinanceAmount(
      text,
      packageName: packageName,
      notificationTitle: notificationTitle,
    )) {
      return false;
    }
    return _walletCardPaymentPattern.hasMatch(text) ||
        _isUniversalTxnTrigger(text) ||
        _strongFinanceSignals.hasMatch(text);
  }

  static final _genericAlertTitlePattern = RegExp(
    r'^(?:unknown|dear customer|customer|wallet|account|payment|money|'
    r'jazzcash|easypaisa|mobilink|sadapay|nayapay|ubl|hbl|mcb|'
    r'transaction alert|money received|money sent|payment received|'
    r'transfer successful|successful transfer|transfer|backup|'
    r'off it goes|money in|money out|cha[\s-]?ching|payment sent|'
    r'payment received|transfer complete|transfer sent|'
    r'raast (?:incoming|outgoing) payment)$',
    caseSensitive: false,
  );

  /// Bank/wallet notification headings — never use as merchant/payee names.
  /// Covers Meezan Bank Alert, Raast Incoming Payment, UBL Transaction Alert, etc.
  static bool _isAlertStyleHeading(String value) {
    final lower = value.trim().toLowerCase();
    if (lower.isEmpty) return false;
    if (_genericMerchants.hasMatch(lower)) return true;
    if (_genericAlertTitlePattern.hasMatch(lower)) return true;
    if (RegExp(
      r'\b(?:alert|notification|helpline|security)\b',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return true;
    }
    if (RegExp(
      r'\b(?:incoming|outgoing|successful)\s+'
      r'(?:payment|transfer|transaction|credit|debit)\b',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return true;
    }
    if (RegExp(
      r'\b(?:payment|transfer|transaction)\s+'
      r'(?:received|sent|successful|complete|failed|alert)\b',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return true;
    }
    if (RegExp(
      r'\b(?:bank|wallet|account)\b.*\b(?:alert|notification)\b|'
      r'\b(?:alert|notification)\b.*\b(?:bank|wallet|account)\b',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return true;
    }
    if (RegExp(
      r'^(?:raast|ibft|1link|upi|imps|neft)\b',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return true;
    }
    return lower.startsWith('off it goes') ||
        lower.startsWith('money in') ||
        lower.startsWith('money out') ||
        (lower.startsWith('cha') && lower.contains('ching'));
  }

  static bool _isGenericNotificationTitle(String value) {
    final v = value.trim();
    if (_genericMerchants.hasMatch(v)) return true;
    if (_isAlertStyleHeading(v)) return true;
    final lower = v.toLowerCase();
    return lower.startsWith('payment sent') ||
        lower.startsWith('payment received') ||
        lower.startsWith('transfer complete') ||
        lower.startsWith('transfer sent') ||
        lower.startsWith('transfer successful');
  }

  /// Person-name notification title (JazzCash, NayaPay, Raqami).
  static final _amountOnlyBodyPattern = RegExp(
    r'^(?:[\s—\-–]*(?:pkr|rs\.?|inr)?[\s]*)?[\d,]+(?:\.\d+)?[\s.—\-–]*$',
    caseSensitive: false,
  );

  static bool _isAmountOnlyBody(String text, {String? notificationTitle}) {
    final t = text.trim();
    if (_amountOnlyBodyPattern.hasMatch(t)) return true;
    final title = notificationTitle?.trim();
    if (title == null || title.isEmpty) return false;
    final combinedPattern = RegExp(
      '^${RegExp.escape(title)}\\s*[—\\-–]\\s*'
      r'(?:[\s]*(?:pkr|rs\.?|inr)?[\s]*)?[\d,]+(?:\.\d+)?[\s.—\-–]*$',
      caseSensitive: false,
    );
    return combinedPattern.hasMatch(t);
  }

  static bool _isPersonNameTitle(String? title) {
    final t = title?.trim();
    if (t == null || t.length < 3) return false;
    if (_isAlertStyleHeading(t)) return false;
    if (_isGenericNotificationTitle(t)) return false;
    if (_genericAlertTitlePattern.hasMatch(t)) return false;
    if (_amountOrAlertTitlePattern.hasMatch(t)) return false;
    // Real person/merchant titles are short name-like strings, not phrases
    // packed with finance verbs ("Incoming Payment", "Money Received").
    if (RegExp(
      r'\b(?:payment|transfer|transaction|alert|incoming|outgoing|'
      r'received|credited|debited|successful)\b',
      caseSensitive: false,
    ).hasMatch(t)) {
      return false;
    }
    return _partyNamePattern.hasMatch(t);
  }

  static final _partyNamePattern = RegExp(
    r"^[A-Za-z\u0600-\u06FF][A-Za-z0-9\u0600-\u06FF .'\-&]{1,48}$",
  );

  static final _amountOrAlertTitlePattern = RegExp(
    r'(?:rs\.?|pkr|inr|₹|₨|usd|eur|gbp|\$|€|£)\s*[\d,]|'
    r'[\d,]+(?:\.\d+)?\s*(?:rs\.?|pkr|inr|₹|₨|usd|eur|gbp|\$|€|£)|'
    r'^(?:you\s+)?(?:have\s+)?(?:received|sent|paid|credited|debited|'
    r'transferred|transfer)\b',
    caseSensitive: false,
  );

  static final _personTitlePattern = RegExp(
    r"^[A-Za-z\u0600-\u06FF][A-Za-z0-9\u0600-\u06FF .'\-&]{1,48}$",
  );

  static bool _hasFinanceAmount(
    String text, {
    String? packageName,
    String? notificationTitle,
  }) {
    return _peekAmount(
          text,
          packageName: packageName,
          notificationTitle: notificationTitle,
        ) !=
        null;
  }

  static double? _amountFromPattern(RegExp pattern, String text) {
    final match = pattern.firstMatch(text);
    if (match == null || match.groupCount < 1) return null;
    return double.tryParse(match.group(1)!.replaceAll(',', ''));
  }

  static bool _hasFinanceContext(String text, {String? packageName}) {
    if (_isHighConfidenceTxn(text)) return true;
    if (MonitoredPackages.matches(packageName)) {
      return _strongFinanceSignals.hasMatch(text) ||
          _monitoredWalletFallback.hasMatch(text) ||
          _walletTxnSignals.hasMatch(text);
    }
    return _hasCurrencyLabel(text) && _strongFinanceSignals.hasMatch(text);
  }

  static double? _peekAmount(
    String text, {
    String? packageName,
    String? notificationTitle,
  }) {
    for (final pattern in [
      _amountOfRsPattern,
      _moneyTransferOfRsPattern,
      _youSentRsPattern,
      _youReceivedRsPattern,
      _receivedInAccountPattern,
      _rsSentToPattern,
      _rsReceivedFromPattern,
      _walletCardPaymentPattern,
      _youPaidAtPattern,
      _cardChargedForPattern,
      _paymentOfPattern,
      _amountHasBeenPattern,
      _amountWasPattern,
      _youPaidPattern,
      _debitedByPattern,
    ]) {
      final amount = _amountFromPattern(pattern, text);
      if (amount != null && amount > 0) return amount;
    }
    final fromCurrency = _amountFromCurrencyLabel(text);
    if (fromCurrency != null) return fromCurrency;
    if (_isPersonNameTitle(notificationTitle) &&
        MonitoredPackages.matches(packageName)) {
      final plain = _amountPlainFinance(text);
      if (plain != null) return plain;
    }
    if (_hasFinanceContext(text, packageName: packageName)) {
      return _amountPlainFinance(text);
    }
    return null;
  }

  static double? _amountFromCurrencyLabel(String text) {
    final patterns = [
      RegExp(
        '$_currencyUnits\\s*([\\d,]+(?:\\.\\d+)?)(?![kmb](?:\\b|/))\\s*/?-?',
        caseSensitive: false,
      ),
      RegExp(
        '([\\d,]+(?:\\.\\d+)?)(?![kmb](?:\\b|/))\\s*/?-?\\s*$_currencyUnits',
        caseSensitive: false,
      ),
    ];
    for (final p in patterns) {
      final match = p.firstMatch(text);
      if (match != null) {
        final start = match.start;
        final end = match.end;
        if (_isInvalidAmountContext(text, start, end)) continue;
        final value = double.tryParse(match.group(1)!.replaceAll(',', ''));
        if (value != null && value > 0) return value;
      }
    }
    return null;
  }

  static bool _isInvalidAmountContext(String text, int start, int end) {
    final before = text.substring(0, start);
    final tail = text.substring(end).trimLeft();
    if (RegExp(r'^(?:mb|gb|kb|tb|%)\b', caseSensitive: false).hasMatch(tail)) {
      return true;
    }
    // Clock times — "05:00 AM", "5:00 PM".
    if (RegExp(r'^:\d{2}\b', caseSensitive: false).hasMatch(tail)) {
      return true;
    }
    // Helpline / phone numbers — +92 21 111 — 331 — 331.
    if (RegExp(
      r'(?:helpline|please\s+(?:immediately\s+)?call)\b',
      caseSensitive: false,
    ).hasMatch(before)) {
      return true;
    }
    if (RegExp(
      r'(?:\+?\d{1,3}[\s-])?(?:\d{2,4}[\s-]+)?\d{0,4}\s*$',
      caseSensitive: false,
    ).hasMatch(before) &&
        RegExp(r'^[—\-–/]\s*\d', caseSensitive: false).hasMatch(tail)) {
      return true;
    }
    final windowEnd = (end + 24).clamp(0, text.length);
    final window = text.substring(start, windowEnd);
    if (RegExp(r'\b(?:crore|lakh|lac|million|billion)\b', caseSensitive: false)
        .hasMatch(window)) {
      return true;
    }
    final raw = text.substring(start, end).replaceAll(',', '');
    final value = int.tryParse(raw);
    if (value != null && value >= 2000 && value <= 2099) {
      final before = text.substring(0, start);
      if (_monthNamesPattern.hasMatch(before) ||
          RegExp(
            r'\b(?:on|from|,|\d{1,2}(?:st|nd|rd|th)?)\s*$',
            caseSensitive: false,
          ).hasMatch(before)) {
        return true;
      }
    }
    return false;
  }

  static final _monthNamesPattern = RegExp(
    r'\b(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|'
    r'jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\b',
    caseSensitive: false,
  );

  static double? _amountPlainFinance(String text) {
    for (final match in _plainAmountPattern.allMatches(text)) {
      final start = match.start;
      final end = match.end;
      if (_isInvalidAmountContext(text, start, end)) continue;
      final raw = match.group(1)!;
      final value = double.tryParse(raw.replaceAll(',', ''));
      if (value != null && value >= 1) return value;
    }
    return null;
  }

  static String buildFingerprint({
    required double amount,
    required DateTime occurredAt,
    required String merchant,
    String? accountRef,
    String? referenceId,
  }) {
    // A unique reference id alone identifies the payment — keep the fingerprint
    // stable across channels (which label merchant/account differently) yet
    // distinct for separate payments that happen to share amount + day.
    if (referenceId != null && referenceId.isNotEmpty) {
      final payload = '${amount.toStringAsFixed(2)}|ref:$referenceId';
      return sha256.convert(utf8.encode(payload)).toString();
    }
    final day = '${occurredAt.year}-${occurredAt.month}-${occurredAt.day}';
    final cleaned = merchant.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final normalizedMerchant =
        cleaned.length > 20 ? cleaned.substring(0, 20) : cleaned;
    final payload =
        '${amount.toStringAsFixed(2)}|$day|$normalizedMerchant|${accountRef ?? ''}';
    return sha256.convert(utf8.encode(payload)).toString();
  }

  static final _creditTitlePattern = RegExp(
    r'money\s+received|payment\s+received|cash\s+received|'
    r'raast\s+incoming\s+payment|incoming\s+payment|'
    r'received\s+(?:rs\.?|pkr|inr|₹|₨|\$|€|£|usd|eur|gbp|money|payment|cash)|'
    r'(?:rs\.?|pkr|inr|₹|₨|\$|€|£|usd|eur|gbp)\s*[\d,]+(?:\.\d+)?\s+received',
    caseSensitive: false,
  );

  static final _debitTitlePattern = RegExp(
    r'money\s+sent|payment\s+sent|transfer\s+successful|'
    r'successfully\s+transferred|sent\s+(?:rs\.?|pkr|inr|₹|₨|\$|€|£|usd|eur|gbp|money|payment)|'
    r'you\s+sent',
    caseSensitive: false,
  );

  TransactionType _detectType(
    String text, {
    String? notificationTitle,
    String? packageName,
  }) {
    final lower = text.toLowerCase();
    final titleLower = notificationTitle?.trim().toLowerCase() ?? '';
    final combined = '$titleLower $lower';

    // Primary wallet / Raast outbound triggers.
    if (_youSentRsPattern.hasMatch(combined) ||
        _rsSentToPattern.hasMatch(combined) ||
        _walletCardPaymentPattern.hasMatch(combined) ||
        _youPaidAtPattern.hasMatch(combined) ||
        _youPaidPattern.hasMatch(combined) ||
        _cardChargedForPattern.hasMatch(combined) ||
        _amountOfRsPattern.hasMatch(combined) ||
        _paymentOfPattern.hasMatch(combined) ||
        _youPaidPattern.hasMatch(combined) ||
        RegExp(r'you\s+(?:just\s+)?sent\b', caseSensitive: false).hasMatch(combined) ||
        RegExp(r'successfully\s+sent', caseSensitive: false).hasMatch(combined) ||
        _moneyTransferOfRsPattern.hasMatch(combined) ||
        (_directionTransferPattern.hasMatch(combined) &&
            combined.contains('outgoing'))) {
      return TransactionType.debit;
    }
    if (_youReceivedRsPattern.hasMatch(combined) ||
        _rsReceivedFromPattern.hasMatch(combined) ||
        _receivedInAccountPattern.hasMatch(combined) ||
        (_directionTransferPattern.hasMatch(combined) &&
            combined.contains('incoming'))) {
      return TransactionType.credit;
    }

    final hasBeen = _amountHasBeenPattern.firstMatch(combined);
    if (hasBeen != null) {
      final verb = hasBeen.group(2)!.toLowerCase();
      if (const {'credited', 'received'}.contains(verb)) {
        return TransactionType.credit;
      }
      return TransactionType.debit;
    }

    final was = _amountWasPattern.firstMatch(combined);
    if (was != null) {
      final verb = was.group(2)!.toLowerCase();
      if (const {'credited', 'received'}.contains(verb)) {
        return TransactionType.credit;
      }
      return TransactionType.debit;
    }

    if (titleLower.isNotEmpty) {
      if (_creditTitlePattern.hasMatch(titleLower)) {
        return TransactionType.credit;
      }
      if (_debitTitlePattern.hasMatch(titleLower)) {
        return TransactionType.debit;
      }
    }

    const creditWords = [
      'credited',
      'received',
      'deposited',
      'salary',
      'refund',
      'cashback',
      'added to',
      'added',
      'got',
    ];
    const debitWords = [
      'debited',
      'spent',
      'paid',
      'charged',
      'withdrawn',
      'sent',
      'transferred',
      'deducted',
      'purchase',
      'debit',
    ];

    for (final w in creditWords) {
      if (lower.contains(w) || titleLower.contains(w)) {
        return TransactionType.credit;
      }
    }
    for (final w in debitWords) {
      if (lower.contains(w) || titleLower.contains(w)) {
        return TransactionType.debit;
      }
    }

    // Person-name title + amount-only: default to sent/debit (NayaPay, JazzCash).
    // Received alerts usually include "received" / "Money Received" in title/body.
    if (MonitoredPackages.matches(packageName) &&
        titleLower.isNotEmpty &&
        _isUsablePartyName(notificationTitle) &&
        !_hasCreditSignal(lower, titleLower)) {
      return TransactionType.debit;
    }

    return TransactionType.debit;
  }

  bool _hasCreditSignal(String bodyLower, String titleLower) {
    if (_creditTitlePattern.hasMatch(titleLower)) return true;
    const creditWords = [
      'credited',
      'received',
      'deposited',
      'refund',
      'cashback',
      'added to',
      'added',
    ];
    for (final w in creditWords) {
      if (bodyLower.contains(w) || titleLower.contains(w)) return true;
    }
    return false;
  }

  bool _hasDebitSignal(String bodyLower, String titleLower) {
    if (_debitTitlePattern.hasMatch(titleLower)) return true;
    const debitWords = [
      'debited',
      'spent',
      'paid',
      'withdrawn',
      'sent',
      'transferred',
      'deducted',
      'purchase',
      'debit',
    ];
    for (final w in debitWords) {
      if (bodyLower.contains(w) || titleLower.contains(w)) return true;
    }
    return false;
  }

  double? _extractAmount(
    String text, {
    String? packageName,
    String? notificationTitle,
  }) {
    return TransactionParser._peekAmount(
      text,
      packageName: packageName,
      notificationTitle: notificationTitle,
    );
  }

  String? _extractMerchant(String text, {TransactionType? type}) {
    final patterns = [
      // Easypaisa debit-card SMS: "paid Rs. 1,100.00 at MERCHANT … on 2026-07-08"
      RegExp(
        r'you\s+(?:have\s+)?paid\s+(?:'
        r'(?:rs\.?|pkr|inr|₹|₨)\s*[\d,]+(?:\.\d+)?\s+)?'
        r'at\s+(.+?)\s+on\s+(?:\d{4}-\d{2}-\d{2}|\d{2}-[A-Za-z]{3}-\d{4})\b',
        caseSensitive: false,
      ),
      RegExp(
        r'you\s+(?:have\s+)?paid\s+(?:'
        r'(?:rs\.?|pkr|inr|₹|₨)\s*[\d,]+(?:\.\d+)?\s+)?'
        r'at\s+' +
            _partyCaptureLazy +
            r'(?=\s+(?:on|via|at|for|from|ref|trx|txn|\d{4}-\d{2}-\d{2})|\s*[,.]|$)',
        caseSensitive: false,
      ),
      // UBL card: "charged … for PKR 5,000.00 at VALENCIA S."
      RegExp(
        r'(?:PKR|Rs\.?|INR|₹|₨)\.?\s*[\d,]+(?:\.\d+)?\s+at\s+' +
            _partyCaptureLazy +
            r'(?=\s*[.…]|\s*$)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:to|at|for)\s+' +
            _partyCaptureLazy +
            r'(?=\s+(?:on|via|at|for|from|ref|trx|txn|\d{4}-\d{2}-\d{2})|\s*[,.]|$)',
        caseSensitive: false,
      ),
      RegExp(r'Info:\s*([A-Za-z0-9/.\-]+)', caseSensitive: false),
    ];
    for (final p in patterns) {
      final match = p.firstMatch(text);
      if (match != null) {
        final value = _trimMerchant(match.group(1)!.trim());
        if (value.length >= 2 &&
            _isUsableMerchant(value) &&
            !_isGenericFromTarget(value)) {
          return value;
        }
      }
    }

    // Wallet/bank notifications often lead with "Counterparty Name. …" in the title.
    // Only split on em-dash / pipe — ISO dates (2026-07-08) use ASCII hyphens.
    for (final segment in text.split(RegExp(r'\s*[—|]\s*'))) {
      final trimmed = segment.trim();
      if (_isGenericNotificationTitle(trimmed)) continue;
      if (RegExp(
        r'^(?:txn|trx|debit\s+card|transaction\s+id|transaction)\b',
        caseSensitive: false,
      ).hasMatch(trimmed)) {
        continue;
      }
      final leading = _nameBeforeSentenceDot(trimmed);
      if (leading != null && leading.length >= 2) return leading;
    }

    final fromMatches = RegExp(
      r'from\s+' + _partyCapture,
      caseSensitive: false,
    ).allMatches(text);
    for (final match in fromMatches) {
      final value = _trimMerchant(match.group(1)!.trim());
      if (value.length >= 2 &&
          _isUsableMerchant(value) &&
          !_isGenericFromTarget(value) &&
          !_isPhoneLike(value)) {
        // For debits, "from your account" is common — prefer "to Name" instead.
        if (type == TransactionType.debit) continue;
        return value;
      }
    }

    return null;
  }

  /// PK wallet titles and bodies often use "Name. rest of alert" — keep only
  /// the part before the first sentence dot (not decimals like 500.00).
  String? _nameBeforeSentenceDot(String segment) {
    if (segment.isEmpty) return null;
    if (_isAlertStyleHeading(segment)) return null;
    if (RegExp(
      r'^(?:you |pkr|rs\.?|inr|₹|dear |payment |money |jazzcash|easypaisa|'
      r'transaction |transfer |sent |received |raast |login )',
      caseSensitive: false,
    ).hasMatch(segment)) {
      return null;
    }

    final truncated = _truncateAtSentenceDot(segment);
    if (truncated.length >= 2 && truncated.length < segment.length) {
      return truncated;
    }

    if (segment.endsWith('.') && !RegExp(r'\d\.$').hasMatch(segment)) {
      final withoutDot = segment.substring(0, segment.length - 1).trim();
      if (withoutDot.length >= 2) return withoutDot;
    }
    return null;
  }

  /// First period that is not part of a decimal amount or a dotted initial
  /// (e.g. M.ARHAM).
  static String _truncateAtSentenceDot(String value) {
    final pattern = RegExp(r'(?<!\d)\.(?!\d)');
    for (final match in pattern.allMatches(value)) {
      if (match.start == 0) continue;
      final before = value[match.start - 1];
      final after = match.end < value.length ? value[match.end] : '';
      if (RegExp(r'[A-Za-z]').hasMatch(before) &&
          RegExp(r'[A-Z]').hasMatch(after)) {
        continue;
      }
      return value.substring(0, match.start).trim();
    }
    return value.trim();
  }

  /// Cuts off trailing noise that often follows a merchant name in bank/UPI
  /// messages (e.g. "Starbucks on 12/06" -> "Starbucks", "Amazon Ref 123" ->
  /// "Amazon").
  String _trimMerchant(String value) {
    var v = _truncateAtSentenceDot(value);
    final boundary = RegExp(
      r'\s+(?:on|in|via|ref|refno|a/c|ac|upi|info|bal|avl|available|dated|date|'
      r'txn|trxn|id|using|through|towards|not|will|has|is|from)\b.*$',
      caseSensitive: false,
    );
    v = v.replaceAll(boundary, '');
    v = v.replaceAll(
      RegExp(r'\s+of\s+(?:IBAN|iban)\b.*$', caseSensitive: false),
      '',
    );
    // Raast / IBAN tail glued to a person name — "NAME PK**UNILPKKARTG…" or "NAME PK"
    v = v.replaceAll(RegExp(r'\s+PK(?:[\*A-Z0-9].*)?$', caseSensitive: false), '');
    // JazzCash: "MUHAMMAD ARHAM BABAR AC ********244200101"
    v = v.replaceAll(RegExp(r'\s+AC\b.*$', caseSensitive: false), '');
    // Strip a trailing standalone number/date fragment and punctuation.
    v = v.replaceAll(RegExp(r'\s+\d[\d/.\-]*$'), '');
    v = v.replaceAll(RegExp(r'[\s.,;:\-]+$'), '').trim();
    // Trailing emoji / symbols after a person name — "Mohammad Haris Imran 💸"
    v = v.replaceAll(
      RegExp(
        r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE00}-\u{FE0F}\u{200D}]+$',
        unicode: true,
      ),
      '',
    ).trim();
    return v.isEmpty ? value : v;
  }

  String? _extractAccountRef(String text) {
    final match = RegExp(
      r'(?:A/c|A/C|Account)\s*\*+\s*(\d{4})',
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(1);
  }

  /// Pulls sender/receiver names when a message mentions both sides of a
  /// transfer, or a single counterparty for debit/credit alerts.
  (String?, String?) _extractTransferParties(
    String text,
    TransactionType type,
  ) {
    final fromTo = RegExp(
      r'from\s+' + _partyCaptureLazy + r'\s+to\s+' + _partyCapture,
      caseSensitive: false,
    ).firstMatch(text);
    if (fromTo != null) {
      return (
        _trimMerchant(fromTo.group(1)!.trim()),
        _trimMerchant(fromTo.group(2)!.trim()),
      );
    }

    final successfullySentTo = RegExp(
      r'(?:amount\s+of\s+(?:rs\.?|pkr)\s*[\d,]+(?:\.\d+)?\s+)?'
      r'(?:has\s+been\s+)?successfully\s+sent\s+to\s+' +
          _partyCaptureLazy +
          r'(?=\s+(?:of\s+(?:IBAN|iban|A/C|a/c)|in\s+\*+|via\b|on\b|from\b|trx|tid|\d{4}-\d{2}-\d{2})|\s*[,.]|$)',
      caseSensitive: false,
    ).firstMatch(text);
    if (successfullySentTo != null) {
      final name = _trimMerchant(successfullySentTo.group(1)!.trim());
      if (_isUsablePartyName(name)) return (null, name);
    }

    final youJustSentTo = _youJustSentToPattern.firstMatch(text);
    if (youJustSentTo != null) {
      final name = _trimMerchant(youJustSentTo.group(1)!.trim());
      if (_isUsablePartyName(name)) return (null, name);
    }

    final sentTo = RegExp(
      r'(?:you\s+(?:just\s+)?)?(?:sent|paid|transferred|transfer(?:red)?)\s+(?:'
      r'(?:rs\.?|pkr|inr|₹|₨)\s*[\d,]+(?:\.\d+)?\s+)?'
      r'(?:to|for)\s+' +
          _partyCaptureLazy +
          r'(?=\s+(?:of\s+(?:IBAN|iban|A/C|a/c)|in\s+\*+|via\b|on\b|from\b|trx|tid|\d{4}-\d{2}-\d{2})|\s*[,.]|\s[^\w\s-]|$)',
      caseSensitive: false,
    ).firstMatch(text);
    if (sentTo != null) {
      final name = _trimMerchant(sentTo.group(1)!.trim());
      if (_isUsablePartyName(name)) return (null, name);
    }

    final paidAt = RegExp(
      r'you\s+(?:have\s+)?paid\s+(?:'
      r'(?:rs\.?|pkr|inr|₹|₨)\s*[\d,]+(?:\.\d+)?\s+)?'
      r'at\s+' + _partyCaptureLazy + r'(?=\s+(?:on|via|at|for|from|ref|trx|txn|\d{4}-\d{2}-\d{2})|\s*[,.]|$)',
      caseSensitive: false,
    ).firstMatch(text);
    if (paidAt != null) {
      final name = _trimMerchant(paidAt.group(1)!.trim());
      if (_isUsablePartyName(name)) return (null, name);
    }

    final rsSentToName = RegExp(
      r'(?:rs\.?|pkr|inr|₹|₨)\.?\s*[\d,]+(?:\.\d+)?\s+sent\s+to\s+' +
          _partyCaptureLazy +
          r'(?=\s+(?:of\s+(?:IBAN|iban|A/C|a/c)|in\s+\*+|via\b|on\b|from\b|trx|tid|\d{4}-\d{2}-\d{2})|\s*[,.]|\s[^\w\s-]|$)',
      caseSensitive: false,
    ).firstMatch(text);
    if (rsSentToName != null) {
      final name = _trimMerchant(rsSentToName.group(1)!.trim());
      if (_isUsablePartyName(name)) return (null, name);
    }

    final amountSentTo = RegExp(
      r'(?:rs\.?|pkr|inr|₹|₨)\s*[\d,]+(?:\.\d+)?\s+'
      r'(?:sent|paid|transferred)\s+(?:to|for)\s+' + _partyCapture,
      caseSensitive: false,
    ).firstMatch(text);
    if (amountSentTo != null) {
      final name = _trimMerchant(amountSentTo.group(1)!.trim());
      if (_isUsablePartyName(name)) return (null, name);
    }

    final transferredTo = RegExp(
      r'(?:successfully\s+)?transferred\s+to\s+' + _partyCapture,
      caseSensitive: false,
    ).firstMatch(text);
    if (transferredTo != null) {
      final name = _trimMerchant(transferredTo.group(1)!.trim());
      if (_isUsablePartyName(name)) return (null, name);
    }

    final amountReceivedFrom = RegExp(
      r'(?:rs\.?|pkr|inr|₹|₨)\s*[\d,]+(?:\.\d+)?\s+'
      r'received\s+from\s+' +
          _partyCaptureLazy +
          r'(?=\s+(?:AC\b|PK\b|in\s+your|via\b|on\b|trx|tid|\d{4}-\d{2}-\d{2})|\s*[,.]|$)',
      caseSensitive: false,
    ).firstMatch(text);
    if (amountReceivedFrom != null) {
      final name = _trimMerchant(amountReceivedFrom.group(1)!.trim());
      if (_isUsablePartyName(name)) return (name, null);
    }

    final receivedFrom = RegExp(
      r'(?:have\s+)?(?:received|credited|credit(?:ed)?)\s+(?:'
      r'(?:rs\.?|pkr|inr|₹|₨)\s*[\d,]+(?:\.\d+)?\s+)?'
      r'from\s+' + _partyCapture,
      caseSensitive: false,
    ).firstMatch(text);
    if (receivedFrom != null) {
      final name = _trimMerchant(receivedFrom.group(1)!.trim());
      if (_isUsablePartyName(name)) return (name, null);
    }

    // Easypaisa / PK wallets: "received Rs.1 in your account … from NAME PK**…"
    final inAccountFrom = RegExp(
      r'in\s+your\s+(?:\w+\s+){0,2}account\b[^.]*?\s+from\s+' +
          _partyCaptureLazy,
      caseSensitive: false,
    ).firstMatch(text);
    if (inAccountFrom != null) {
      final name = _trimMerchant(inAccountFrom.group(1)!.trim());
      if (_isUsablePartyName(name)) return (name, null);
    }

    final amountFirstCredit = RegExp(
      r'(?:rs\.?|pkr|inr|₹|₨)\s*[\d,]+(?:\.\d+)?\s+'
      r'(?:has been\s+)?(?:received|credited)\s+from\s+' +
          _partyCapture,
      caseSensitive: false,
    ).firstMatch(text);
    if (amountFirstCredit != null) {
      final name = _trimMerchant(amountFirstCredit.group(1)!.trim());
      if (_isUsablePartyName(name)) return (name, null);
    }

    final amountFrom = RegExp(
      r'(?:rs\.?|pkr|inr|₹|₨)\s*[\d,]+(?:\.\d+)?\s+from\s+' + _partyCapture,
      caseSensitive: false,
    ).firstMatch(text);
    if (amountFrom != null) {
      final name = _trimMerchant(amountFrom.group(1)!.trim());
      if (_isUsablePartyName(name)) return (name, null);
    }

    return (null, null);
  }

  /// Combines a message date/time with [fallbackTime] (notification/SMS stamp).
  DateTime? _extractOccurredAt(String text, {DateTime? fallbackTime}) {
    final dateHit = _findDateMatch(text);
    final time = _extractTimeOfDay(
      text,
      preferAfterIndex: dateHit?.end,
      fallbackTime: fallbackTime,
    );

    if (dateHit != null) {
      final date = dateHit.date;
      if (time != null) {
        return DateTime(date.year, date.month, date.day, time.$1, time.$2);
      }
      // Body has a calendar day but no usable clock — keep the notification
      // clock when it lands on/near that day so list order stays correct.
      if (fallbackTime != null &&
          _isSameOrNearbyDay(date, fallbackTime)) {
        return DateTime(
          date.year,
          date.month,
          date.day,
          fallbackTime.hour,
          fallbackTime.minute,
        );
      }
      return date;
    }

    // Date missing (e.g. em-dash mangled) but body has a clock — use notify day.
    if (time != null && fallbackTime != null) {
      return DateTime(
        fallbackTime.year,
        fallbackTime.month,
        fallbackTime.day,
        time.$1,
        time.$2,
      );
    }
    return null;
  }

  static bool _isSameOrNearbyDay(DateTime date, DateTime fallback) {
    final dayOnly = DateTime(date.year, date.month, date.day);
    final fallbackDay = DateTime(fallback.year, fallback.month, fallback.day);
    return fallbackDay.difference(dayOnly).abs() <= const Duration(hours: 36);
  }

  /// Extracts an HH:MM clock. Seconds are dropped so cross-channel alerts
  /// land on the same minute. Prefers the txn clock over balance/as-of times.
  (int, int)? _extractTimeOfDay(
    String text, {
    int? preferAfterIndex,
    DateTime? fallbackTime,
  }) {
    final pattern = RegExp(
      r'\b(\d{1,2}):(\d{2})(?::\d{2}(?:\.\d+)?)?\s*(a\.?m\.?|p\.?m\.?)?',
      caseSensitive: false,
    );

    final candidates = <_ClockCandidate>[];
    for (final match in pattern.allMatches(text)) {
      final parsed = _parseClockMatch(match);
      if (parsed == null) continue;
      final beforeStart = (match.start - 28).clamp(0, text.length);
      final before = text.substring(beforeStart, match.start).toLowerCase();
      final isBalanceClock = RegExp(
        r'(?:available|avl|current|new)?\s*bal(?:ance)?|as\s+of\b',
        caseSensitive: false,
      ).hasMatch(before);
      final nearTxnVerb = RegExp(
        r'(?:charged|debited|credited|paid|sent|received|withdrawn|'
        r'transferred|purchase|on)\b',
        caseSensitive: false,
      ).hasMatch(before);
      candidates.add(
        _ClockCandidate(
          hour: parsed.$1,
          minute: parsed.$2,
          start: match.start,
          hasMeridiem: match.group(3) != null,
          isBalanceClock: isBalanceClock,
          nearTxnVerb: nearTxnVerb,
        ),
      );
    }
    if (candidates.isEmpty) return null;

    // Prefer a clock shortly after the matched transaction date ("on … at …").
    final afterIndex = preferAfterIndex;
    if (afterIndex != null) {
      final afterDate = candidates.where((c) {
        final delta = c.start - afterIndex;
        return delta >= 0 && delta <= 48;
      }).toList();
      final pick = _bestClock(afterDate, fallbackTime);
      if (pick != null) return (pick.hour, pick.minute);
    }

    // Explicit "at HH:MM" near a money-movement verb.
    final atClocks = candidates.where((c) {
      if (c.isBalanceClock) return false;
      final from = (c.start - 4).clamp(0, text.length);
      return RegExp(r'\bat\s+$', caseSensitive: false)
          .hasMatch(text.substring(from, c.start));
    }).toList();
    final atPick = _bestClock(atClocks, fallbackTime);
    if (atPick != null) return (atPick.hour, atPick.minute);

    final nonBalance = candidates.where((c) => !c.isBalanceClock).toList();
    final pick = _bestClock(
      nonBalance.isNotEmpty ? nonBalance : candidates,
      fallbackTime,
    );
    if (pick == null) return null;
    return (pick.hour, pick.minute);
  }

  static _ClockCandidate? _bestClock(
    List<_ClockCandidate> candidates,
    DateTime? fallbackTime,
  ) {
    if (candidates.isEmpty) return null;
    candidates = [...candidates]..sort((a, b) {
        // Prefer clocks with AM/PM and near txn wording.
        final scoreA = (a.hasMeridiem ? 4 : 0) +
            (a.nearTxnVerb ? 2 : 0) -
            (a.isBalanceClock ? 6 : 0);
        final scoreB = (b.hasMeridiem ? 4 : 0) +
            (b.nearTxnVerb ? 2 : 0) -
            (b.isBalanceClock ? 6 : 0);
        if (scoreA != scoreB) return scoreB.compareTo(scoreA);
        if (fallbackTime != null) {
          final fa = _minutesFromMidnight(a.hour, a.minute);
          final fb = _minutesFromMidnight(b.hour, b.minute);
          final fr = fallbackTime.hour * 60 + fallbackTime.minute;
          final da = (fa - fr).abs();
          final db = (fb - fr).abs();
          // Also consider +12h for bare 1–12 clocks without meridiem.
          final daAlt = a.hasMeridiem
              ? da
              : [da, (fa + 12 * 60 - fr).abs() % (24 * 60)].reduce(
                  (x, y) => x < y ? x : y,
                );
          final dbAlt = b.hasMeridiem
              ? db
              : [db, (fb + 12 * 60 - fr).abs() % (24 * 60)].reduce(
                  (x, y) => x < y ? x : y,
                );
          if (daAlt != dbAlt) return daAlt.compareTo(dbAlt);
        }
        return b.start.compareTo(a.start);
      });

    var best = candidates.first;
    // Bare afternoon clocks often omit AM/PM — snap to the notify half-day.
    if (!best.hasMeridiem &&
        fallbackTime != null &&
        best.hour >= 1 &&
        best.hour <= 12) {
      final asIs = DateTime(
        fallbackTime.year,
        fallbackTime.month,
        fallbackTime.day,
        best.hour,
        best.minute,
      );
      final plus12 = DateTime(
        fallbackTime.year,
        fallbackTime.month,
        fallbackTime.day,
        best.hour == 12 ? 12 : best.hour + 12,
        best.minute,
      );
      if ((plus12.difference(fallbackTime).abs()) <
          (asIs.difference(fallbackTime).abs())) {
        best = _ClockCandidate(
          hour: plus12.hour,
          minute: best.minute,
          start: best.start,
          hasMeridiem: true,
          isBalanceClock: best.isBalanceClock,
          nearTxnVerb: best.nearTxnVerb,
        );
      }
    }
    return best;
  }

  static int _minutesFromMidnight(int hour, int minute) => hour * 60 + minute;

  static (int, int)? _parseClockMatch(RegExpMatch match) {
    var hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return null;
    if (minute > 59) return null;
    final rawMeridiem = match.group(3)?.toLowerCase().replaceAll('.', '');
    if (rawMeridiem == 'pm' && hour < 12) hour += 12;
    if (rawMeridiem == 'am' && hour == 12) hour = 0;
    if (hour > 23) return null;
    return (hour, minute);
  }

  /// First plausible calendar date in [text], with its match end index.
  _DateHit? _findDateMatch(String text) {
    final monthNames = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };

    // 15-Jul-26 / 15/Jul/2026
    final named = RegExp(
      r'(\d{1,2})[-/](\w{3})[-/](\d{2,4})',
      caseSensitive: false,
    ).firstMatch(text);
    if (named != null) {
      final d = int.tryParse(named.group(1)!);
      final m = monthNames[named.group(2)!.toLowerCase()];
      var y = int.tryParse(named.group(3)!);
      if (d != null && m != null && y != null) {
        if (y < 100) y += 2000;
        final date = _validDate(y, m, d);
        if (date != null) {
          return _DateHit(date: date, end: named.end);
        }
      }
    }

    // Meezan / sanitized: "13 — Jul — 2026"
    final spacedNamed = RegExp(
      r'(\d{1,2})\s*[—–\-]\s*([A-Za-z]{3})\s*[—–\-]\s*(\d{2,4})',
      caseSensitive: false,
    ).firstMatch(text);
    if (spacedNamed != null) {
      final d = int.tryParse(spacedNamed.group(1)!);
      final m = monthNames[spacedNamed.group(2)!.toLowerCase()];
      var y = int.tryParse(spacedNamed.group(3)!);
      if (d != null && m != null && y != null) {
        if (y < 100) y += 2000;
        final date = _validDate(y, m, d);
        if (date != null) {
          return _DateHit(date: date, end: spacedNamed.end);
        }
      }
    }

    final iso = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(text);
    if (iso != null) {
      final y = int.tryParse(iso.group(1)!);
      final m = int.tryParse(iso.group(2)!);
      final d = int.tryParse(iso.group(3)!);
      if (y != null && m != null && d != null) {
        final date = _validDate(y, m, d);
        if (date != null) return _DateHit(date: date, end: iso.end);
      }
    }

    final slash = RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})').firstMatch(text);
    if (slash == null) return null;

    final d = int.tryParse(slash.group(1)!);
    final m = int.tryParse(slash.group(2)!);
    var y = int.tryParse(slash.group(3)!);
    if (d == null || m == null || y == null) return null;
    if (y < 100) y += 2000;

    final date = _validDate(y, m, d);
    if (date == null) return null;
    return _DateHit(date: date, end: slash.end);
  }

  DateTime? _validDate(int y, int m, int d) {
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final date = DateTime(y, m, d);
    if (date.year != y || date.month != m || date.day != d) return null;

    final now = DateTime.now();
    if (date.isAfter(now.add(const Duration(days: 1)))) return null;
    if (date.isBefore(DateTime(now.year - 3))) return null;

    return date;
  }
}

class _DateHit {
  const _DateHit({required this.date, required this.end});

  final DateTime date;
  final int end;
}

class _ClockCandidate {
  const _ClockCandidate({
    required this.hour,
    required this.minute,
    required this.start,
    required this.hasMeridiem,
    required this.isBalanceClock,
    required this.nearTxnVerb,
  });

  final int hour;
  final int minute;
  final int start;
  final bool hasMeridiem;
  final bool isBalanceClock;
  final bool nearTxnVerb;
}
