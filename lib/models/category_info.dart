import 'package:flutter/material.dart';

/// Display + storage identity for a spending category (built-in or custom).
class CategoryInfo {
  const CategoryInfo({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    this.isCustom = false,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final bool isCustom;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryInfo && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
