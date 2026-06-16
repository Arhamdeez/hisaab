import 'package:flutter/material.dart';

/// HISAAB palette.
///
/// Design intent: a deep, warm near-black base with a single confident red
/// accent. Neutrals are warm-toned (not cool slate) so they sit naturally on
/// the maroon ambience. Secondary colours are muted/desaturated so nothing
/// competes with the brand red.
abstract final class AppColors {
  // Base surfaces — warm near-black.
  static const background = Color(0xFF0B0809);
  static const backgroundElevated = Color(0xFF140F10);
  static const surface = Color(0x08FFFFFF);
  static const surfaceHigh = Color(0x12FFFFFF);
  static const surfaceMuted = Color(0x06FFFFFF);

  // Brand accent — a single, confident red.
  static const primary = Color(0xFFE5544E);
  static const primaryDim = Color(0xFFB8413C);
  static const primaryGlow = Color(0xFFF07A75);

  static const accent = primary;

  // Status colours — muted, refined (not neon).
  static const income = Color(0xFF5FB98C);
  static const saved = Color(0xFF6E9BD0);
  static const expense = Color(0xFFE07570);
  static const warning = Color(0xFFD9A152);

  // Text — warm neutrals.
  static const textPrimary = Color(0xFFF4F1EF);
  static const textSecondary = Color(0xFFCBC3C0);
  static const textOnPrimary = Color(0xFFFFFFFF);
  static const textMuted = Color(0xFF9A918D);
  static const textDim = Color(0xFF6E6562);

  // Lines & shadows.
  static const border = Color(0x1AFFFFFF);
  static const borderLight = Color(0x2EFFFFFF);
  static const shadow = Color(0x66000000);

  // Glass surfaces — iOS liquid glass: translucent, luminous edges.
  static const glassFill = Color(0x08FFFFFF);
  static const glassFillStrong = Color(0x10FFFFFF);
  static const glassBorder = Color(0x38FFFFFF);
  static const glassHighlight = Color(0x1AFFFFFF);

  // Ambient maroon glow (kept subtle).
  static const glowMaroon = Color(0xFF3E1414);
  static const glowMaroonDeep = Color(0xFF2A0E0F);
  static const glowWine = Color(0xFF551B1B);

  static const gradientStart = Color(0xFF1C0E0F);
  static const gradientMid = Color(0xFF130A0B);
  static const gradientEnd = Color(0xFF0B0809);

  static const navBar = Color(0x00000000);
}
