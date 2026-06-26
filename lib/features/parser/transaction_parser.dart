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
    this.occurredAt,
    this.senderName,
    this.receiverName,
  });

  final double amount;
  final TransactionType type;
  final String merchant;
  final SpendingCategory category;
  final double confidence;
  final String? accountRef;
  final DateTime? occurredAt;

  /// Counterparty sending money (credit alerts). May be null when unknown.
  final String? senderName;

  /// Counterparty receiving money (debit alerts). May be null when unknown.
  final String? receiverName;
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
    final segments = text.split(RegExp(r'\s*[—\-|]\s*'));
    final kept = <String>[];
    for (final segment in segments) {
      final t = segment.trim();
      if (t.isEmpty) continue;
      if (_metadataSegmentPattern.hasMatch(t)) continue;
      kept.add(t);
    }
    return kept.join(' — ');
  }

  static final _metadataSegmentPattern = RegExp(
    r'(?:android\.(?:app|x)\.|androidx\.|Notification\$|NotificationCompat|'
    r'FCM-Notification|BigTextStyle|MessagingStyle|InboxStyle|'
    r'^com\.[a-z0-9_.]+\s*$)',
    caseSensitive: false,
  );

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
    r'\b(?:missed\s+call|incoming\s+call|voice\s+mail)\b|'
    r'\b(?:weather|forecast|rain\s+alert)\b|'
    r'\b(?:match\s+score|full\s+time)\b|'
    r'\b(?:get\s+a\s+chance|chance\s+to\s+win|win\s+(?:\d+|a\s+|1\s)|'
    r'(?:\d+\s+)?crore|(?:\d+\s+)?lakh|(?:\d+\s+)?lac)\b|'
    r'\bmaintain\s+(?:rs\.?|pkr)\b|'
    r'\b(?:refer(?:ral)?|invite\s+(?:friends?|and\s+earn))\b|'
    r'\b\d+\s*(?:mb|gb|kb|tb)\s+of\s+\d+\s*(?:mb|gb|kb|tb)\b|'
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
    r'\b(?:\d+\s*)?(?:gb|mb)\s*,\s*\d+\s+(?:other\s+)?(?:network\s+)?min',
    caseSensitive: false,
  );

  /// Strong money-movement wording — required for unknown apps (with currency).
  static final _strongFinanceSignals = RegExp(
    r'debited|credited|withdrawn|deducted|spent|transferred|purchase|'
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
    r'a/c\s*\*+|account\s*\*+|trx\s*id|trans(?:action)?\s*id|t(?:xn|rxn)\s*no',
    caseSensitive: false,
  );

  // Signals real money movement — aligned with Android IngestPlugin.walletTxnRegex.
  static final _walletTxnSignals = RegExp(
    r'debited|credited|spent|withdrawn|deducted|transferred|received|'
    r'\bpaid\b|\bsent\b|purchase|\btxn\b|transaction|\bdebit\b|\bcredit\b|'
    r'refund|cashback|deposited|salary|transfer|withdrawal|'
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
    final amount = _extractAmount(normalized, packageName: packageName);
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
    final occurredAt = _extractDate(normalized) ?? fallbackTime;
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
      occurredAt: occurredAt,
      senderName: senderName,
      receiverName: receiverName,
    );
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
    // Body "from/to" patterns are more reliable than notification titles, which
    // are often generic ("Money received") or amount-only ("Rs.500 received").
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

    final fromTitle = _extractMerchantFromTitle(notificationTitle);
    if (_isUsablePartyName(fromTitle)) return fromTitle;

    final extracted = _extractMerchant(text, type: type);
    if (_isUsablePartyName(extracted)) return extracted;

    if (_isUsableMerchant(fromTitle) && !_isPhoneLike(fromTitle!)) {
      return fromTitle;
    }
    return extracted;
  }

  String? _extractMerchantFromTitle(String? title) {
    if (title == null) return null;
    final trimmed = title.trim();
    if (trimmed.isEmpty ||
        _isGenericAlertTitle(trimmed) ||
        _isAmountOrAlertTitle(trimmed)) {
      return null;
    }

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
        _debitedByPattern.hasMatch(text) ||
        _paymentOfPattern.hasMatch(text) ||
        _amountHasBeenPattern.hasMatch(text) ||
        _amountWasPattern.hasMatch(text) ||
        _youPaidPattern.hasMatch(text) ||
        (_directionTransferPattern.hasMatch(text) &&
            _amountFromCurrencyLabel(text) != null) ||
        (_successfulTxnPattern.hasMatch(text) &&
            _amountFromCurrencyLabel(text) != null);
  }

  static bool _isHighConfidenceTxn(String text) {
    return _isUniversalTxnTrigger(text);
  }

  static bool _isNoiseNotification(String text) =>
      _noiseNotificationPattern.hasMatch(text);

  static bool _hasCurrencyLabel(String text) =>
      _amountFromCurrencyLabel(text) != null;

  static bool _looksLikeTransaction(
    String text, {
    String? packageName,
    String? notificationTitle,
  }) {
    if (MonitoredPackages.isExcluded(packageName)) return false;
    if (_isNoiseNotification(text)) return false;

    // Tier 1 — explicit payment phrasing from any app (incl. Gmail).
    if (_isHighConfidenceTxn(text)) return true;

    final isFinanceApp = MonitoredPackages.matches(packageName);
    final isEmail = MonitoredPackages.isEmailClient(packageName);

    if (isEmail) {
      return _hasCurrencyLabel(text) && _strongFinanceSignals.hasMatch(text);
    }

    if (isFinanceApp) {
      if (!_hasFinanceAmount(text, packageName: packageName)) {
        return false;
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

    // Unknown apps: currency label + strong finance wording only.
    return _hasCurrencyLabel(text) && _strongFinanceSignals.hasMatch(text);
  }

  /// Merchant/person in title + amount in body (Google Wallet, JazzCash, NayaPay).
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
    if (!_hasFinanceAmount(text, packageName: packageName)) return false;
    return _walletCardPaymentPattern.hasMatch(text) ||
        _walletTxnSignals.hasMatch(text) ||
        _strongFinanceSignals.hasMatch(text) ||
        _hasCurrencyLabel(text);
  }

  static final _genericAlertTitlePattern = RegExp(
    r'^(?:unknown|dear customer|customer|wallet|account|payment|money|'
    r'jazzcash|easypaisa|mobilink|sadapay|nayapay|ubl|hbl|mcb|'
    r'transaction alert|money received|money sent|payment received|'
    r'transfer successful|successful transfer|transfer|backup|'
    r'off it goes|money in|money out|cha[\s-]?ching|payment sent|'
    r'payment received|transfer complete|transfer sent)$',
    caseSensitive: false,
  );

  static bool _isGenericNotificationTitle(String value) {
    final v = value.trim();
    if (_genericMerchants.hasMatch(v)) return true;
    final lower = v.toLowerCase();
    return lower.startsWith('off it goes') ||
        lower.startsWith('money in') ||
        lower.startsWith('money out') ||
        (lower.startsWith('cha') && lower.contains('ching')) ||
        lower.startsWith('payment sent') ||
        lower.startsWith('payment received') ||
        lower.startsWith('transfer complete') ||
        lower.startsWith('transfer sent') ||
        lower.startsWith('transfer successful');
  }

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

  static bool _hasFinanceAmount(String text, {String? packageName}) {
    return _peekAmount(text, packageName: packageName) != null;
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

  static double? _peekAmount(String text, {String? packageName}) {
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
    final tail = text.substring(end).trimLeft();
    if (RegExp(r'^(?:mb|gb|kb|tb|%)\b', caseSensitive: false).hasMatch(tail)) {
      return true;
    }
    final windowEnd = (end + 24).clamp(0, text.length);
    final window = text.substring(start, windowEnd);
    if (RegExp(r'\b(?:crore|lakh|lac|million|billion)\b', caseSensitive: false)
        .hasMatch(window)) {
      return true;
    }
    return false;
  }

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
  }) {
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

  double? _extractAmount(String text, {String? packageName}) {
    return TransactionParser._peekAmount(text, packageName: packageName);
  }

  String? _extractMerchant(String text, {TransactionType? type}) {
    final patterns = [
      RegExp(
        r'you\s+(?:have\s+)?paid\s+(?:'
        r'(?:rs\.?|pkr|inr|₹|₨)\s*[\d,]+(?:\.\d+)?\s+)?'
        r'at\s+' +
            _partyCaptureLazy +
            r'(?=\s+(?:on|via|at|for|from|ref|trx|txn|\d{4}-\d{2}-\d{2})|\s*[,.]|$)',
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
    for (final segment in text.split(RegExp(r'\s*[—\-|]\s*'))) {
      final trimmed = segment.trim();
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
    if (RegExp(
      r'^(?:you |pkr|rs\.?|inr|₹|dear |payment |money |jazzcash|easypaisa|'
      r'transaction |transfer |sent |received )',
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

  /// First period that is not part of a decimal amount.
  static String _truncateAtSentenceDot(String value) {
    final match = RegExp(r'(?<!\d)\.(?!\d)').firstMatch(value);
    if (match != null && match.start > 0) {
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
      r'txn|trxn|id|using|through|towards|not|will|has|is)\b.*$',
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

  DateTime? _extractDate(String text) {
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
        if (date != null) return date;
      }
    }

    final iso = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(text);
    if (iso != null) {
      final y = int.tryParse(iso.group(1)!);
      final m = int.tryParse(iso.group(2)!);
      final d = int.tryParse(iso.group(3)!);
      if (y != null && m != null && d != null) {
        final date = _validDate(y, m, d);
        if (date != null) return date;
      }
    }

    final slash = RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})').firstMatch(text);
    if (slash == null) return null;

    final d = int.tryParse(slash.group(1)!);
    final m = int.tryParse(slash.group(2)!);
    var y = int.tryParse(slash.group(3)!);
    if (d == null || m == null || y == null) return null;
    if (y < 100) y += 2000;

    return _validDate(y, m, d);
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
