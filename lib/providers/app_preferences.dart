import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/transaction.dart';

import '../features/dedup/review_policy.dart';

/// User-facing display preferences persisted locally.
class AppPreferences extends ChangeNotifier {
  AppPreferences._(
    this._prefs, {
    bool showIncome = false,
    double monthlyIncome = 0,
    Map<String, double>? incomeByMonth,
    bool trackInwardFlow = true,
    bool settingsTourSeen = false,
    bool homeTourSeen = false,
    String accountHolderName = '',
  })  : _showIncome = showIncome,
        _monthlyIncome = monthlyIncome,
        _incomeByMonth = incomeByMonth ?? <String, double>{},
        _trackInwardFlow = trackInwardFlow,
        _settingsTourSeen = settingsTourSeen,
        _homeTourSeen = homeTourSeen,
        _accountHolderName = accountHolderName;

  static const _showIncomeKey = 'show_income';
  static const _monthlyIncomeKey = 'monthly_income';
  static const _incomeByMonthKey = 'monthly_income_by_month';
  static const _trackInwardFlowKey = 'track_inward_flow';
  static const _settingsTourSeenKey = 'settings_tour_seen';
  static const _homeTourSeenKey = 'home_tour_seen';
  static const _accountHolderNameKey = 'account_holder_name';

  static AppPreferences? _instance;
  static Future<void>? _hydrating;

  /// Singleton used by [Provider]. Self-heals after hot reload.
  static AppPreferences get instance {
    final existing = _instance;
    if (existing != null) {
      existing._repairAfterHotReload();
      return existing;
    }
    _instance = AppPreferences._(null);
    _hydrate();
    return _instance!;
  }

  SharedPreferences? _prefs;

  // Nullable backing fields so hot reload never leaves a live singleton with
  // uninitialized bools (which crash on read).
  bool? _showIncome;
  double? _monthlyIncome;
  Map<String, double>? _incomeByMonth;
  bool? _trackInwardFlow;
  bool? _settingsTourSeen;
  bool? _homeTourSeen;
  String? _accountHolderName;

  /// Off by default for new users — enable in Settings when you want a budget.
  bool get showIncome => _showIncome ?? false;

  bool get hasSeenSettingsTour => _settingsTourSeen ?? false;

  bool get hasSeenHomeTour => _homeTourSeen ?? false;

  /// When enabled, the app tracks cash received (credits) from alerts and
  /// manual entry, and surfaces inward flow across Home, Transactions, and
  /// Reports.
  bool get trackInwardFlow => _trackInwardFlow ?? true;

  /// Legacy baseline monthly income (PKR). Acts as the fallback for any month
  /// that has no explicit override and no earlier override to carry forward.
  double get monthlyIncome => _monthlyIncome ?? 0;

  bool get hasMonthlyIncome => monthlyIncome > 0;

  /// Explicit per-month income overrides, keyed by `YYYY-MM`.
  Map<String, double> get _overrides => _incomeByMonth ??= <String, double>{};

  static String _monthKey(DateTime month) =>
      '${month.year.toString().padLeft(4, '0')}-'
      '${month.month.toString().padLeft(2, '0')}';

  /// Resolves the declared income for [month] using carry-forward: the most
  /// recent month at or before [month] with an explicit value wins, otherwise
  /// the legacy baseline is used. Returns 0 when nothing is set.
  double incomeForMonth(DateTime month) {
    final key = _monthKey(month);
    final overrides = _overrides;
    if (overrides.containsKey(key)) return overrides[key]!;

    String? bestKey;
    for (final entry in overrides.keys) {
      if (entry.compareTo(key) <= 0 &&
          (bestKey == null || entry.compareTo(bestKey) > 0)) {
        bestKey = entry;
      }
    }
    if (bestKey != null) return overrides[bestKey]!;
    return monthlyIncome;
  }

  /// Whether [month] resolves to a positive declared income.
  bool hasIncomeForMonth(DateTime month) => incomeForMonth(month) > 0;

  /// Whether [month] carries an explicit override (vs inherited/baseline).
  bool hasIncomeOverrideForMonth(DateTime month) =>
      _overrides.containsKey(_monthKey(month));

  /// Legal/account name on bank & wallet alerts — used to detect self-transfers.
  String get accountHolderName => _accountHolderName ?? '';

  bool get hasAccountHolderName => accountHolderName.trim().isNotEmpty;

  void _repairAfterHotReload() {
    _showIncome ??= false;
    _monthlyIncome ??= 0;
    _incomeByMonth ??= <String, double>{};
    _trackInwardFlow ??= true;
    _settingsTourSeen ??= false;
    _homeTourSeen ??= false;
    _accountHolderName ??= '';
  }

  static Map<String, double> _decodeOverrides(String? raw) {
    if (raw == null || raw.isEmpty) return <String, double>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(
            key.toString(),
            (value is num) ? value.toDouble() : 0.0,
          ),
        )..removeWhere((_, value) => value <= 0);
      }
    } catch (_) {
      // Corrupt payload — start clean rather than crashing.
    }
    return <String, double>{};
  }

  static Future<AppPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final showIncome = prefs.getBool(_showIncomeKey) ?? false;
    final monthlyIncome = prefs.getDouble(_monthlyIncomeKey) ?? 0;
    final incomeByMonth = _decodeOverrides(prefs.getString(_incomeByMonthKey));
    final trackInwardFlow = prefs.getBool(_trackInwardFlowKey) ?? true;
    final settingsTourSeen = prefs.getBool(_settingsTourSeenKey) ?? false;
    final homeTourSeen = prefs.getBool(_homeTourSeenKey) ?? false;
    final accountHolderName = prefs.getString(_accountHolderNameKey) ?? '';

    if (_instance != null) {
      _instance!._prefs = prefs;
      _instance!._showIncome = showIncome;
      _instance!._monthlyIncome = monthlyIncome;
      _instance!._incomeByMonth = incomeByMonth;
      _instance!._trackInwardFlow = trackInwardFlow;
      _instance!._settingsTourSeen = settingsTourSeen;
      _instance!._homeTourSeen = homeTourSeen;
      _instance!._accountHolderName = accountHolderName;
      _instance!.notifyListeners();
    } else {
      _instance = AppPreferences._(
        prefs,
        showIncome: showIncome,
        monthlyIncome: monthlyIncome,
        incomeByMonth: incomeByMonth,
        trackInwardFlow: trackInwardFlow,
        settingsTourSeen: settingsTourSeen,
        homeTourSeen: homeTourSeen,
        accountHolderName: accountHolderName,
      );
    }

    return _instance!;
  }

  static void _hydrate() {
    _hydrating ??= load().whenComplete(() => _hydrating = null);
  }

  Future<void> setShowIncome(bool value) async {
    if (showIncome == value) return;
    _showIncome = value;
    notifyListeners();
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setBool(_showIncomeKey, value);
  }

  /// Sets the income for [month]. With carry-forward resolution this value
  /// also applies to later months until another override is set, while earlier
  /// months keep whatever they already resolved to. A value of 0 clears the
  /// override for [month] (it will then inherit from an earlier month again).
  Future<void> setMonthlyIncomeForMonth(double value, DateTime month) async {
    final clamped = value < 0 ? 0.0 : value;
    final key = _monthKey(month);
    final overrides = Map<String, double>.from(_overrides);

    if (clamped <= 0) {
      if (!overrides.containsKey(key)) return;
      overrides.remove(key);
    } else {
      if (overrides[key] == clamped) return;
      overrides[key] = clamped;
    }

    _incomeByMonth = overrides;
    notifyListeners();
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    if (overrides.isEmpty) {
      await prefs.remove(_incomeByMonthKey);
    } else {
      await prefs.setString(_incomeByMonthKey, jsonEncode(overrides));
    }
  }

  Future<void> setTrackInwardFlow(bool value) async {
    if (trackInwardFlow == value) return;
    _trackInwardFlow = value;
    notifyListeners();
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setBool(_trackInwardFlowKey, value);
  }

  Future<void> markSettingsTourSeen() async {
    if (hasSeenSettingsTour) return;
    _settingsTourSeen = true;
    notifyListeners();
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setBool(_settingsTourSeenKey, true);
  }

  Future<void> markHomeTourSeen() async {
    if (hasSeenHomeTour) return;
    _homeTourSeen = true;
    notifyListeners();
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setBool(_homeTourSeenKey, true);
  }

  Future<void> setAccountHolderName(String value) async {
    final trimmed = value.trim();
    if (ReviewPolicy.normalizeName(accountHolderName) ==
        ReviewPolicy.normalizeName(trimmed)) {
      return;
    }
    _accountHolderName = trimmed;
    notifyListeners();
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    if (trimmed.isEmpty) {
      await prefs.remove(_accountHolderNameKey);
    } else {
      await prefs.setString(_accountHolderNameKey, trimmed);
    }
  }

  /// Learns the account holder from "Dear NAME," wallet/bank greetings.
  Future<void> learnAccountHolderName(String? candidate) async {
    final trimmed = candidate?.trim();
    if (trimmed == null || trimmed.isEmpty) return;

    final current = accountHolderName;
    if (current.isEmpty) {
      await setAccountHolderName(trimmed);
      return;
    }
    if (ReviewPolicy.namesMatch(current, trimmed)) {
      if (trimmed.length > current.length) {
        await setAccountHolderName(trimmed);
      }
    }
  }

  /// Income baseline for the budget slider — only when [showIncome] is on.
  /// The declared income for [month] wins (with carry-forward); otherwise
  /// credits from confirmed transactions for that month are used.
  double resolveIncome(MonthlySummary summary, DateTime month) {
    if (!showIncome) return 0;
    final declared = incomeForMonth(month);
    if (declared > 0) return declared;
    return summary.totalCredit;
  }
}
