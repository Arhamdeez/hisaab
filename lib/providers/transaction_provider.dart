import 'package:flutter/foundation.dart';

import '../core/repositories/transaction_repository.dart';
import '../features/dedup/deduplicator.dart';
import '../features/parser/category_guesser.dart';
import '../features/parser/transaction_parser.dart';
import '../models/transaction.dart';

class TransactionProvider extends ChangeNotifier {
  TransactionProvider({
    required TransactionRepository repository,
    required Deduplicator deduplicator,
  })  : _repository = repository,
        _deduplicator = deduplicator;

  final TransactionRepository _repository;
  final Deduplicator _deduplicator;

  List<Transaction> _transactions = [];
  DateTime _selectedMonth = DateTime.now();
  bool _loaded = false;

  String? _summaryCacheKey;
  MonthlySummary? _summaryCache;
  final Map<String, List<Transaction>> _monthTxCache = {};

  List<Transaction> get transactions => List.unmodifiable(_transactions);
  DateTime get selectedMonth => _selectedMonth;
  bool get isLoaded => _loaded;

  List<Transaction> get confirmedTransactions => _transactions
      .where((t) => t.status == TransactionStatus.confirmed)
      .toList();

  List<Transaction> get pendingTransactions => _transactions
      .where((t) => t.status == TransactionStatus.pendingReview)
      .toList();

  /// Total items awaiting review across every month. The header bell and the
  /// "needs review" banner use this so a freshly captured transaction always
  /// surfaces, even if its date lands outside the currently selected month.
  int get pendingCount => pendingTransactions.length;

  Future<void> load() async {
    _transactions = await _repository.getAll();
    _loaded = true;
    _invalidateCaches();
    notifyListeners();
  }

  void _invalidateCaches() {
    _summaryCacheKey = null;
    _summaryCache = null;
    _monthTxCache.clear();
  }

  static String _monthKey(DateTime month) => '${month.year}-${month.month}';

  Future<void> reload() => load();

  List<Transaction> transactionsForMonth(DateTime month) {
    final key = _monthKey(month);
    return _monthTxCache.putIfAbsent(key, () {
      return confirmedTransactions
          .where(
            (t) =>
                t.occurredAt.year == month.year &&
                t.occurredAt.month == month.month,
          )
          .toList();
    });
  }

  /// Newest confirmed transactions for [month], for home "latest activity".
  List<Transaction> recentForMonth(DateTime month, {int limit = 5}) {
    final sorted = List<Transaction>.from(transactionsForMonth(month))
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    if (sorted.length <= limit) return sorted;
    return sorted.sublist(0, limit);
  }

  MonthlySummary summaryForMonth(DateTime month) {
    final key = _monthKey(month);
    if (_summaryCacheKey == key && _summaryCache != null) {
      return _summaryCache!;
    }
    final txs = transactionsForMonth(month);
    final debits = txs.where((t) => t.isDebit);
    final credits = txs.where((t) => !t.isDebit);

    final totalDebit = debits.fold<double>(0, (s, t) => s + t.amount);
    final totalCredit = credits.fold<double>(0, (s, t) => s + t.amount);

    final categoryMap = <String, CategorySummary>{};
    for (final t in debits) {
      final existing = categoryMap[t.categoryId];
      categoryMap[t.categoryId] = CategorySummary(
        categoryId: t.categoryId,
        total: (existing?.total ?? 0) + t.amount,
        count: (existing?.count ?? 0) + 1,
      );
    }

    final bySource = <TransactionSource, double>{};
    for (final t in debits) {
      bySource[t.source] = (bySource[t.source] ?? 0) + t.amount;
    }

    final merchantMap = <String, double>{};
    for (final t in debits) {
      merchantMap[t.merchant] = (merchantMap[t.merchant] ?? 0) + t.amount;
    }
    final topMerchants = merchantMap.entries
        .map((e) => (merchant: e.key, total: e.value))
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final daily = List<double>.filled(daysInMonth, 0);
    for (final t in debits) {
      daily[t.occurredAt.day - 1] += t.amount;
    }

    final pending = _transactions.where((t) {
      return t.isPending &&
          t.occurredAt.year == month.year &&
          t.occurredAt.month == month.month;
    }).length;

    final result = MonthlySummary(
      year: month.year,
      month: month.month,
      totalDebit: totalDebit,
      totalCredit: totalCredit,
      byCategory: categoryMap.values.toList()
        ..sort((a, b) => b.total.compareTo(a.total)),
      dailySpending: daily,
      transactionCount: txs.length,
      pendingCount: pending,
      bySource: bySource,
      topMerchants: topMerchants.take(5).toList(),
    );
    _summaryCacheKey = key;
    _summaryCache = result;
    return result;
  }

  void setSelectedMonth(DateTime month) {
    _selectedMonth = DateTime(month.year, month.month);
    notifyListeners();
  }

  Future<void> confirmTransaction(
    String id, {
    String? categoryId,
  }) async {
    if (categoryId != null) {
      await _repository.applyReview(
        id,
        status: TransactionStatus.confirmed,
        categoryId: categoryId,
      );
    } else {
      await _repository.updateStatus(id, TransactionStatus.confirmed);
    }
    await load();
  }

  /// Best category for a pending transaction using history + merchant text.
  CategorySuggestion suggestCategory(Transaction transaction) {
    return CategoryGuesser.suggest(
      merchant: transaction.merchant,
      rawText: transaction.rawText,
      parsedCategory: SpendingCategoryX.fromKey(transaction.categoryId),
      confirmedHistory: confirmedTransactions,
    );
  }

  /// Confirms with auto-detected category when confident; otherwise null so the
  /// UI can show the picker sheet.
  Future<bool> tryAutoConfirmTransaction(String id) async {
    Transaction? tx;
    for (final t in _transactions) {
      if (t.id == id) {
        tx = t;
        break;
      }
    }
    if (tx == null || !tx.isPending) return false;

    if (!tx.isDebit) {
      await confirmTransaction(
        id,
        categoryId: SpendingCategory.other.storageKey,
      );
      return true;
    }

    final suggestion = suggestCategory(tx);
    if (!suggestion.isConfident) return false;

    await confirmTransaction(id, categoryId: suggestion.categoryId);
    return true;
  }

  Future<void> ignoreTransaction(String id) async {
    await _repository.updateStatus(id, TransactionStatus.ignored);
    await load();
  }

  Future<void> addManualTransaction({
    required double amount,
    required String merchant,
    required String categoryId,
    required TransactionType type,
  }) async {
    final now = DateTime.now();
    final fingerprint = TransactionParser.buildFingerprint(
      amount: amount,
      occurredAt: now,
      merchant: merchant,
    );

    await _repository.save(
      Transaction(
        id: now.millisecondsSinceEpoch.toString(),
        amount: amount,
        type: type,
        merchant: merchant,
        categoryId: categoryId,
        occurredAt: now,
        source: TransactionSource.manual,
        status: TransactionStatus.confirmed,
        fingerprint: fingerprint,
      ),
    );
    await load();
  }

  Future<void> ingestRawMessage({
    required String text,
    required TransactionSource source,
    DateTime? timestamp,
  }) async {
    final parser = TransactionParser();
    final rules = await _repository.getParserRules();
    if (rules.isNotEmpty) parser.updateRules(rules);

    final parsed = parser.parse(
      text,
      source: source,
      fallbackTime: timestamp ?? DateTime.now(),
    );
    if (parsed == null) return;

    await _deduplicator.processIncoming(
      parsed: parsed,
      source: source,
      rawText: text,
      messageTime: timestamp ?? DateTime.now(),
    );
    await load();
  }

  int countForCategory(String categoryId) =>
      _transactions.where((t) => t.categoryId == categoryId).length;

  Future<void> reassignCategory(String fromId, String toId) async {
    await _repository.reassignCategory(fromId, toId);
    await load();
  }

  Future<void> updateTransactionCategory(String id, String categoryId) async {
    await _repository.updateCategory(id, categoryId);
    await load();
  }
}
