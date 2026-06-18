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
  ];

  void updateRules(List<ParserRule> rules) {
    _rules
      ..clear()
      ..addAll(rules);
  }

  // Signals real money movement — aligned with Android IngestPlugin.walletTxnRegex.
  static final _walletTxnSignals = RegExp(
    r'debited|credited|spent|withdrawn|deducted|transferred|received|'
    r'\bpaid\b|\bsent\b|purchase|\btxn\b|transaction|\bdebit\b|\bcredit\b|'
    r'refund|cashback|deposited|salary|transfer|withdrawal|'
    r'payment|charged|\bbill\b|added|successful|'
    r'money\s+received|money\s+sent|payment\s+received|payment\s+sent|'
    r'transfer\s*successful|successfully\s*transferred|'
    r'you\s+sent|sent\s+to|transfer\s+to|transfer\s+from|'
    r'sent\s*(?:rs|pkr)|received\s*(?:rs|pkr)|'
    r'a/c\s*\*+|account\s*\*+|trx\s*id|trans(?:action)?\s*id|t(?:xn|rxn)\s*no|'
    r'has\s*been\s*(?:debited|credited|deducted)',
    caseSensitive: false,
  );

  ParsedTransaction? parse(
    String text, {
    required TransactionSource source,
    DateTime? fallbackTime,
    String? packageName,
    String? notificationTitle,
  }) {
    final normalized = text.replaceAll('\n', ' ').trim();
    if (normalized.isEmpty) return null;

    if (!_looksLikeTransaction(normalized, packageName: packageName)) {
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
        _youReceivedRsPattern.hasMatch(normalized)) {
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
    r'^(?:your|my|the|a|an|wallet|account|customer|a/c|ac\b|bank)\b',
    caseSensitive: false,
  );

  bool _isGenericFromTarget(String value) => _genericFromTargets.hasMatch(value);

  bool _isGenericAlertTitle(String value) {
    return _genericMerchants.hasMatch(value.trim());
  }

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

  static final _plainAmountPattern = RegExp(
    r'\b([1-9]\d{0,2}(?:,\d{3})+(?:\.\d{2})?|[1-9]\d{2,7}(?:\.\d{2})?)\b',
  );

  /// Primary PK wallet alert shape: "You sent Rs. 1,500.00 …"
  static final _youSentRsPattern = RegExp(
    r'you\s+sent\s+(?:PKR|Rs\.?|INR|₹|₨)\.?\s*([\d,]+(?:\.\d+)?)',
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
        _youReceivedRsPattern.hasMatch(combined)) {
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

  static bool _looksLikeTransaction(String text, {String? packageName}) {
    if (MonitoredPackages.isExcluded(packageName)) return false;
    // Strongest PK wallet trigger — works even outside the finance-app list.
    if (_youSentRsPattern.hasMatch(text) || _youReceivedRsPattern.hasMatch(text)) {
      return true;
    }
    final amount = _peekAmount(text, packageName: packageName);
    if (amount == null || amount <= 0) return false;
    if (_walletTxnSignals.hasMatch(text)) return true;
    // Bank / wallet apps often post amount (+ name in title) only.
    if (MonitoredPackages.matches(packageName)) return true;
    return false;
  }

  static double? _peekAmount(String text, {String? packageName}) {
    final sent = _youSentRsPattern.firstMatch(text);
    if (sent != null) {
      return double.tryParse(sent.group(1)!.replaceAll(',', ''));
    }
    final received = _youReceivedRsPattern.firstMatch(text);
    if (received != null) {
      return double.tryParse(received.group(1)!.replaceAll(',', ''));
    }
    final fromCurrency = _amountFromCurrencyLabel(text);
    if (fromCurrency != null) return fromCurrency;
    if (MonitoredPackages.matches(packageName)) {
      return _amountPlainFinance(text);
    }
    return null;
  }

  static double? _amountFromCurrencyLabel(String text) {
    final patterns = [
      RegExp(
        '$_currencyUnits\\s*([\\d,]+(?:\\.\\d+)?)',
        caseSensitive: false,
      ),
      RegExp(
        '([\\d,]+(?:\\.\\d+)?)\\s*$_currencyUnits',
        caseSensitive: false,
      ),
    ];
    for (final p in patterns) {
      final match = p.firstMatch(text);
      if (match != null) {
        return double.tryParse(match.group(1)!.replaceAll(',', ''));
      }
    }
    return null;
  }

  static double? _amountPlainFinance(String text) {
    for (final match in _plainAmountPattern.allMatches(text)) {
      final raw = match.group(1)!;
      final value = double.tryParse(raw.replaceAll(',', ''));
      if (value != null && value >= 10) return value;
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

    // Primary PK wallet outbound trigger.
    if (_youSentRsPattern.hasMatch(combined) ||
        RegExp(r'you\s+sent\b', caseSensitive: false).hasMatch(combined)) {
      return TransactionType.debit;
    }
    if (_youReceivedRsPattern.hasMatch(combined)) {
      return TransactionType.credit;
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
    // Wallet/bank notifications often lead with "Counterparty Name. …" in the title.
    for (final segment in text.split(RegExp(r'\s*[—\-|]\s*'))) {
      final leading = _nameBeforeSentenceDot(segment.trim());
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

    final patterns = [
      RegExp(
        r'(?:to|at|for)\s+' + _partyCapture,
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
      r'\s+(?:on|via|ref|refno|a/c|ac|upi|info|bal|avl|available|dated|date|'
      r'txn|trxn|id|using|through|towards|not|will|has|is)\b.*$',
      caseSensitive: false,
    );
    v = v.replaceAll(boundary, '');
    // Strip a trailing standalone number/date fragment and punctuation.
    v = v.replaceAll(RegExp(r'\s+\d[\d/.\-]*$'), '');
    v = v.replaceAll(RegExp(r'[\s.,;:\-]+$'), '').trim();
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

    final sentTo = RegExp(
      r'(?:you\s+)?(?:sent|paid|transferred|transfer(?:red)?)\s+(?:'
      r'(?:rs\.?|pkr|inr|₹|₨)\s*[\d,]+(?:\.\d+)?\s+)?'
      r'(?:to|for)\s+' + _partyCapture,
      caseSensitive: false,
    ).firstMatch(text);
    if (sentTo != null) {
      final name = _trimMerchant(sentTo.group(1)!.trim());
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
