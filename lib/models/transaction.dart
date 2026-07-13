import 'dart:convert';

import 'package:flutter/material.dart';

enum TransactionType { debit, credit }

enum TransactionSource { notification, sms, gmail, manual }

enum TransactionStatus { pendingReview, confirmed, ignored, failed }

enum SpendingCategory {
  food,
  transport,
  shopping,
  bills,
  entertainment,
  health,
  other,
}

extension SpendingCategoryX on SpendingCategory {
  String get label => switch (this) {
        SpendingCategory.food => 'Food',
        SpendingCategory.transport => 'Transport',
        SpendingCategory.shopping => 'Shopping',
        SpendingCategory.bills => 'Housing',
        SpendingCategory.entertainment => 'Entertainment',
        SpendingCategory.health => 'Health',
        SpendingCategory.other => 'Other',
      };

  String get storageKey => name;

  static SpendingCategory fromKey(String key) =>
      SpendingCategory.values.firstWhere(
        (c) => c.name == key,
        orElse: () => SpendingCategory.other,
      );

  IconData get icon => switch (this) {
        SpendingCategory.food => Icons.restaurant_rounded,
        SpendingCategory.transport => Icons.directions_car_rounded,
        SpendingCategory.shopping => Icons.shopping_bag_rounded,
        SpendingCategory.bills => Icons.receipt_long_rounded,
        SpendingCategory.entertainment => Icons.movie_rounded,
        SpendingCategory.health => Icons.favorite_rounded,
        SpendingCategory.other => Icons.more_horiz_rounded,
      };

  /// Warm vintage tones that stay legible on the dark wine base.
  Color get color => switch (this) {
        SpendingCategory.food => const Color(0xFFD98E52),
        SpendingCategory.transport => const Color(0xFF9DB0A6),
        SpendingCategory.shopping => const Color(0xFFC79AB2),
        SpendingCategory.bills => const Color(0xFFD97A6E),
        SpendingCategory.entertainment => const Color(0xFFCE8AA4),
        SpendingCategory.health => const Color(0xFF7FC0A8),
        SpendingCategory.other => const Color(0xFFAEA6A0),
      };
}

extension TransactionTypeX on TransactionType {
  String get storageKey => name;
  static TransactionType fromKey(String key) =>
      TransactionType.values.firstWhere((t) => t.name == key);
}

extension TransactionSourceX on TransactionSource {
  String get storageKey => name;
  static TransactionSource fromKey(String key) =>
      TransactionSource.values.firstWhere((s) => s.name == key);
}

extension TransactionStatusX on TransactionStatus {
  String get storageKey => name;
  static TransactionStatus fromKey(String key) =>
      TransactionStatus.values.firstWhere((s) => s.name == key);
}

class Transaction {
  const Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.merchant,
    required this.categoryId,
    required this.occurredAt,
    required this.source,
    required this.status,
    required this.fingerprint,
    this.currency = 'PKR',
    this.rawText,
    this.confidence = 1.0,
    this.linkedSources = const [],
    this.description,
  });

  final String id;
  final double amount;
  final String currency;
  final TransactionType type;
  final String merchant;
  final String categoryId;
  final DateTime occurredAt;
  final TransactionSource source;
  final TransactionStatus status;
  final String? rawText;
  final double confidence;
  final String fingerprint;
  final List<TransactionSource> linkedSources;
  final String? description;

  bool get isDebit => type == TransactionType.debit;
  bool get isPending => status == TransactionStatus.pendingReview;
  bool get isFailed => status == TransactionStatus.failed;

  /// When the payment alert was captured (from the id timestamp). Used for
  /// back-to-back transfer detection; falls back to [occurredAt] for manual rows.
  DateTime get capturedAt {
    final head = id.split('_').first;
    final ms = int.tryParse(head);
    if (ms != null && ms > 946684800000) {
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    return occurredAt;
  }

  Transaction copyWith({
    TransactionStatus? status,
    String? categoryId,
    List<TransactionSource>? linkedSources,
    String? description,
  }) {
    return Transaction(
      id: id,
      amount: amount,
      currency: currency,
      type: type,
      merchant: merchant,
      categoryId: categoryId ?? this.categoryId,
      occurredAt: occurredAt,
      source: source,
      status: status ?? this.status,
      rawText: rawText,
      confidence: confidence,
      fingerprint: fingerprint,
      linkedSources: linkedSources ?? this.linkedSources,
      description: description ?? this.description,
    );
  }
}

class CategorySummary {
  const CategorySummary({
    required this.categoryId,
    required this.total,
    required this.count,
  });

  final String categoryId;
  final double total;
  final int count;
}

class MonthlySummary {
  const MonthlySummary({
    required this.year,
    required this.month,
    required this.totalDebit,
    required this.totalCredit,
    required this.byCategory,
    required this.dailySpending,
    required this.transactionCount,
    required this.pendingCount,
    this.bySource = const {},
    this.topMerchants = const [],
  });

  final int year;
  final int month;
  final double totalDebit;
  final double totalCredit;
  final List<CategorySummary> byCategory;
  final List<double> dailySpending;
  final int transactionCount;
  final int pendingCount;
  final Map<TransactionSource, double> bySource;
  final List<({String merchant, double total})> topMerchants;

  double get netCashFlow => totalCredit - totalDebit;
}

List<TransactionSource> linkedSourcesFromJson(String json) {
  try {
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((e) => TransactionSourceX.fromKey(e as String))
        .toList();
  } catch (_) {
    return [];
  }
}

String linkedSourcesToJson(List<TransactionSource> sources) =>
    jsonEncode(sources.map((s) => s.storageKey).toList());
