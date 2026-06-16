import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-facing display preferences persisted locally.
class AppPreferences extends ChangeNotifier {
  AppPreferences._(
    this._prefs, {
    bool showIncome = true,
    double monthlyIncome = 0,
  })  : _showIncome = showIncome,
        _monthlyIncome = monthlyIncome;

  static const _showIncomeKey = 'show_income';
  static const _monthlyIncomeKey = 'monthly_income';

  static AppPreferences? _instance;
  static Future<void>? _hydrating;

  /// Singleton used by [Provider]. Self-heals after hot reload.
  static AppPreferences get instance {
    if (_instance != null) return _instance!;
    _instance = AppPreferences._(null);
    _hydrate();
    return _instance!;
  }

  SharedPreferences? _prefs;
  bool _showIncome;
  double _monthlyIncome;

  bool get showIncome => _showIncome;

  /// Manually declared monthly income (PKR). 0 means "not set" — callers
  /// should fall back to income derived from credit transactions.
  double get monthlyIncome => _monthlyIncome;

  bool get hasMonthlyIncome => _monthlyIncome > 0;

  static Future<AppPreferences> load() async {
    if (_instance?._prefs != null) return _instance!;

    final prefs = await SharedPreferences.getInstance();
    final showIncome = prefs.getBool(_showIncomeKey) ?? true;
    final monthlyIncome = prefs.getDouble(_monthlyIncomeKey) ?? 0;

    if (_instance != null) {
      _instance!._prefs = prefs;
      _instance!._showIncome = showIncome;
      _instance!._monthlyIncome = monthlyIncome;
      _instance!.notifyListeners();
    } else {
      _instance = AppPreferences._(
        prefs,
        showIncome: showIncome,
        monthlyIncome: monthlyIncome,
      );
    }

    return _instance!;
  }

  static void _hydrate() {
    _hydrating ??= load().whenComplete(() => _hydrating = null);
  }

  Future<void> setShowIncome(bool value) async {
    if (_showIncome == value) return;
    _showIncome = value;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setBool(_showIncomeKey, value);
    notifyListeners();
  }

  Future<void> setMonthlyIncome(double value) async {
    final clamped = value < 0 ? 0.0 : value;
    if (_monthlyIncome == clamped) return;
    _monthlyIncome = clamped;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setDouble(_monthlyIncomeKey, clamped);
    notifyListeners();
  }
}
