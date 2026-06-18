import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';
import '../models/category_info.dart';
import '../models/transaction.dart';

class CustomCategoryRecord {
  const CustomCategoryRecord({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
  });

  final String id;
  final String name;
  final int iconCodePoint;
  final int colorValue;

  CategoryInfo toInfo() => CategoryInfo(
        id: id,
        label: name,
        icon: CategoryIconOptions.resolve(iconCodePoint),
        color: Color(colorValue),
        isCustom: true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': iconCodePoint,
        'color': colorValue,
      };

  factory CustomCategoryRecord.fromJson(Map<String, dynamic> json) {
    return CustomCategoryRecord(
      id: json['id'] as String,
      name: json['name'] as String,
      iconCodePoint: json['icon'] as int,
      colorValue: json['color'] as int,
    );
  }
}

/// Built-in + user-defined spending categories.
class CategoryCatalog extends ChangeNotifier {
  CategoryCatalog._(this._prefs, List<CustomCategoryRecord> custom)
      : _custom = List.of(custom);

  static const _storageKey = 'custom_categories';

  static CategoryCatalog? _instance;
  static Future<void>? _hydrating;

  SharedPreferences? _prefs;
  List<CustomCategoryRecord> _custom;

  static CategoryCatalog get instance {
    final existing = _instance;
    if (existing != null) return existing;
    _instance = CategoryCatalog._(null, const []);
    _hydrate();
    return _instance!;
  }

  static Future<CategoryCatalog> load() async {
    final prefs = await SharedPreferences.getInstance();
    final custom = _readCustom(prefs.getString(_storageKey));
    if (_instance != null) {
      _instance!._prefs = prefs;
      _instance!._custom = custom;
      _instance!.notifyListeners();
    } else {
      _instance = CategoryCatalog._(prefs, custom);
    }
    return _instance!;
  }

  static void _hydrate() {
    _hydrating ??= load().whenComplete(() => _hydrating = null);
  }

  static List<CustomCategoryRecord> _readCustom(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((e) => CustomCategoryRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static CategoryInfo builtin(SpendingCategory category) => CategoryInfo(
        id: category.storageKey,
        label: category.label,
        icon: category.icon,
        color: category.color,
      );

  List<CategoryInfo> get builtIn =>
      SpendingCategory.values.map(builtin).toList();

  List<CategoryInfo> get custom =>
      _custom.map((record) => record.toInfo()).toList();

  List<CategoryInfo> get all => [...builtIn, ...custom];

  int get customCount => _custom.length;

  CategoryInfo resolve(String id) {
    for (final category in SpendingCategory.values) {
      if (category.storageKey == id) return builtin(category);
    }
    for (final record in _custom) {
      if (record.id == id) return record.toInfo();
    }
    return builtin(SpendingCategory.other);
  }

  bool isCustomId(String id) => id.startsWith('custom_');

  Future<CategoryInfo> addCustom({
    required String name,
    required IconData icon,
    required Color color,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Category name cannot be empty');
    }
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final record = CustomCategoryRecord(
      id: id,
      name: trimmed,
      iconCodePoint: icon.codePoint,
      colorValue: color.toARGB32(),
    );
    _custom.add(record);
    await _persist();
    notifyListeners();
    return record.toInfo();
  }

  Future<void> renameCustom(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final index = _custom.indexWhere((c) => c.id == id);
    if (index < 0) return;
    final old = _custom[index];
    _custom[index] = CustomCategoryRecord(
      id: old.id,
      name: trimmed,
      iconCodePoint: old.iconCodePoint,
      colorValue: old.colorValue,
    );
    await _persist();
    notifyListeners();
  }

  Future<void> updateCustom({
    required String id,
    String? name,
    IconData? icon,
    Color? color,
  }) async {
    final index = _custom.indexWhere((c) => c.id == id);
    if (index < 0) return;
    final old = _custom[index];
    _custom[index] = CustomCategoryRecord(
      id: old.id,
      name: name?.trim().isNotEmpty == true ? name!.trim() : old.name,
      iconCodePoint: icon?.codePoint ?? old.iconCodePoint,
      colorValue: color?.toARGB32() ?? old.colorValue,
    );
    await _persist();
    notifyListeners();
  }

  Future<bool> removeCustom(String id) async {
    final before = _custom.length;
    _custom.removeWhere((c) => c.id == id);
    if (_custom.length == before) return false;
    await _persist();
    notifyListeners();
    return true;
  }

  Future<void> _persist() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    final encoded = jsonEncode(_custom.map((c) => c.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}

/// Preset icons for new custom categories.
abstract final class CategoryIconOptions {
  static IconData resolve(int codePoint) {
    for (final icon in icons) {
      if (icon.codePoint == codePoint) return icon;
    }
    return icons.first;
  }

  static const icons = [
    Icons.label_outline_rounded,
    Icons.work_outline_rounded,
    Icons.school_outlined,
    Icons.card_giftcard_outlined,
    Icons.pets_outlined,
    Icons.flight_outlined,
    Icons.child_care_outlined,
    Icons.sports_esports_outlined,
    Icons.home_outlined,
    Icons.phone_iphone_outlined,
    Icons.local_cafe_outlined,
    Icons.checkroom_outlined,
  ];
}

/// Preset accent colors for custom categories.
abstract final class CategoryColorOptions {
  static const colors = [
    Color(0xFFD98E52),
    Color(0xFF9DB0A6),
    Color(0xFFC79AB2),
    Color(0xFFD97A6E),
    Color(0xFFCE8AA4),
    Color(0xFF7FC0A8),
    Color(0xFF8FA8D8),
    Color(0xFFE8B86D),
    AppColors.brand,
    Color(0xFFAEA6A0),
  ];
}
