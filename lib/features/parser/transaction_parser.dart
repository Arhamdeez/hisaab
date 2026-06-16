import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../models/transaction.dart';
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
  });

  final double amount;
  final TransactionType type;
  final String merchant;
  final SpendingCategory category;
  final double confidence;
  final String? accountRef;
  final DateTime? occurredAt;
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
          r'(?:debited|spent|paid|withdrawn).*?(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)',
      enabled: true,
    ),
    ParserRule(
      id: 10,
      name: 'Generic Credit',
      pattern:
          r'(?:credited|received|deposited).*?(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)',
      enabled: true,
    ),
  ];

  void updateRules(List<ParserRule> rules) {
    _rules
      ..clear()
      ..addAll(rules);
  }

  // A word that signals real money movement. Required so that promotional or
  // price-tag notifications (which contain an amount but no movement) are not
  // recorded as transactions.
  static final _movementKeywords = RegExp(
    r'debited|credited|spent|withdrawn|deducted|transferred|received|'
    r'\bpaid\b|\bsent\b|purchase|\btxn\b|transaction|\bdebit\b|\bcredit\b|'
    r'refund|cashback|deposited|salary',
    caseSensitive: false,
  );

  ParsedTransaction? parse(
    String text, {
    required TransactionSource source,
    DateTime? fallbackTime,
  }) {
    final normalized = text.replaceAll('\n', ' ').trim();
    if (normalized.isEmpty) return null;

    // Must describe an actual transaction, not just mention a price.
    if (!_movementKeywords.hasMatch(normalized)) return null;

    final type = _detectType(normalized);
    final amount = _extractAmount(normalized);
    if (amount == null || amount <= 0) return null;

    final merchant = _extractMerchant(normalized) ?? 'Unknown';
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
    confidence = confidence.clamp(0.0, 1.0);

    return ParsedTransaction(
      amount: amount,
      type: type,
      merchant: merchant,
      category: category,
      confidence: confidence,
      accountRef: accountRef,
      occurredAt: occurredAt,
    );
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

  TransactionType _detectType(String text) {
    final lower = text.toLowerCase();
    const creditWords = [
      'credited',
      'received',
      'deposited',
      'salary',
      'refund',
      'cashback',
      'added to',
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
      if (lower.contains(w)) return TransactionType.credit;
    }
    for (final w in debitWords) {
      if (lower.contains(w)) return TransactionType.debit;
    }
    return TransactionType.debit;
  }

  double? _extractAmount(String text) {
    final patterns = [
      RegExp(
        r'(?:Rs\.?|PKR|INR|₹|₨)\s*([\d,]+(?:\.\d+)?)',
        caseSensitive: false,
      ),
      RegExp(
        r'([\d,]+(?:\.\d+)?)\s*(?:Rs\.?|PKR|INR|₹|₨)',
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

  String? _extractMerchant(String text) {
    final patterns = [
      RegExp(
        r'(?:to|at|for|from)\s+([A-Za-z0-9][A-Za-z0-9 &.\-]{1,39})',
        caseSensitive: false,
      ),
      RegExp(r'Info:\s*([A-Za-z0-9/.\-]+)', caseSensitive: false),
    ];
    for (final p in patterns) {
      final match = p.firstMatch(text);
      if (match != null) {
        final value = _trimMerchant(match.group(1)!.trim());
        if (value.length >= 2) return value;
      }
    }
    return null;
  }

  /// Cuts off trailing noise that often follows a merchant name in bank/UPI
  /// messages (e.g. "Starbucks on 12/06" -> "Starbucks", "Amazon Ref 123" ->
  /// "Amazon").
  String _trimMerchant(String value) {
    final boundary = RegExp(
      r'\s+(?:on|via|ref|refno|a/c|ac|upi|info|bal|avl|available|dated|date|'
      r'txn|trxn|id|using|through|towards|not|will|has|is)\b.*$',
      caseSensitive: false,
    );
    var v = value.replaceAll(boundary, '');
    // Strip a trailing standalone number/date fragment and punctuation.
    v = v.replaceAll(RegExp(r'\s+\d[\d/.\-]*$'), '');
    v = v.replaceAll(RegExp(r'[\s.,;:\-]+$'), '').trim();
    return v.isEmpty ? value : v;
  }

  String? _extractAccountRef(String text) {
    final match = RegExp(
      r'A/c\s*\*+\s*(\d{4})',
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(1);
  }

  DateTime? _extractDate(String text) {
    final slash = RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})').firstMatch(text);
    if (slash != null) {
      try {
        final d = int.parse(slash.group(1)!);
        final m = int.parse(slash.group(2)!);
        var y = int.parse(slash.group(3)!);
        if (y < 100) y += 2000;
        return DateTime(y, m, d);
      } catch (_) {}
    }
    return null;
  }
}
