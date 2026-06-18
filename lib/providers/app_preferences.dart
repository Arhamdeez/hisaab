import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/transaction.dart';

/// User-facing display preferences persisted locally.
class AppPreferences extends ChangeNotifier {
  AppPreferences._(
    this._prefs, {
    bool showIncome = false,
    double monthlyIncome = 0,
    bool trackInwardFlow = false,
    bool settingsTourSeen = false,
    bool homeTourSeen = false,
  })  : _showIncome = showIncome,
        _monthlyIncome = monthlyIncome,
        _trackInwardFlow = trackInwardFlow,
        _settingsTourSeen = settingsTourSeen,
        _homeTourSeen = homeTourSeen;

  static const _showIncomeKey = 'show_income';
  static const _monthlyIncomeKey = 'monthly_income';
  static const _trackInwardFlowKey = 'track_inward_flow';
  static const _settingsTourSeenKey = 'settings_tour_seen';
  static const _homeTourSeenKey = 'home_tour_seen';

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
  bool? _trackInwardFlow;
  bool? _settingsTourSeen;
  bool? _homeTourSeen;

  /// Off by default for new users — enable in Settings when you want a budget.
  bool get showIncome => _showIncome ?? false;

  bool get hasSeenSettingsTour => _settingsTourSeen ?? false;

  bool get hasSeenHomeTour => _homeTourSeen ?? false;

  /// When enabled, the app tracks cash received (credits) from alerts and
  /// manual entry, and surfaces inward flow across Home, Transactions, and
  /// Reports. Off by default — outflow/spending only.
  bool get trackInwardFlow => _trackInwardFlow ?? false;

  /// Manually declared monthly income (PKR). 0 means "not set" — callers
  /// should fall back to income derived from credit transactions.
  double get monthlyIncome => _monthlyIncome ?? 0;

  bool get hasMonthlyIncome => monthlyIncome > 0;

  void _repairAfterHotReload() {
    _showIncome ??= false;
    _monthlyIncome ??= 0;
    _trackInwardFlow ??= false;
    _settingsTourSeen ??= false;
    _homeTourSeen ??= false;
  }

  static Future<AppPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final showIncome = prefs.getBool(_showIncomeKey) ?? false;
    final monthlyIncome = prefs.getDouble(_monthlyIncomeKey) ?? 0;
    final trackInwardFlow = prefs.getBool(_trackInwardFlowKey) ?? false;
    final settingsTourSeen = prefs.getBool(_settingsTourSeenKey) ?? false;
    final homeTourSeen = prefs.getBool(_homeTourSeenKey) ?? false;

    if (_instance != null) {
      _instance!._prefs = prefs;
      _instance!._showIncome = showIncome;
      _instance!._monthlyIncome = monthlyIncome;
      _instance!._trackInwardFlow = trackInwardFlow;
      _instance!._settingsTourSeen = settingsTourSeen;
      _instance!._homeTourSeen = homeTourSeen;
      _instance!.notifyListeners();
    } else {
      _instance = AppPreferences._(
        prefs,
        showIncome: showIncome,
        monthlyIncome: monthlyIncome,
        trackInwardFlow: trackInwardFlow,
        settingsTourSeen: settingsTourSeen,
        homeTourSeen: homeTourSeen,
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

  Future<void> setMonthlyIncome(double value) async {
    final clamped = value < 0 ? 0.0 : value;
    if (monthlyIncome == clamped) return;
    _monthlyIncome = clamped;
    notifyListeners();
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setDouble(_monthlyIncomeKey, clamped);
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

  /// Income baseline for the budget slider — only when [showIncome] is on.
  /// Manual monthly income wins; otherwise credits from confirmed transactions.
  double resolveIncome(MonthlySummary summary) {
    if (!showIncome) return 0;
    if (hasMonthlyIncome) return monthlyIncome;
    return summary.totalCredit;
  }
}
