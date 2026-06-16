import 'package:flutter/material.dart';

/// Frosty black — monochrome glass UI; brand red for logo only;
/// green/red reserved for cash in / cash out.
abstract final class AppColors {
  // Brand — logo & wordmark accent only.
  static const brand = Color(0xFFE84842);
  static const brandGlow = Color(0xFFFF6B63);
  static const brandDim = Color(0xFFB8322C);

  /// Legacy aliases used by the logo mark.
  static const primary = brand;
  static const primaryGlow = brandGlow;
  static const primaryDim = brandDim;

  // UI chrome — frosty white (buttons, nav, focus rings, accents).
  static const ui = Color(0xFFFFFFFF);
  static const uiMuted = Color(0x99FFFFFF);
  static const accent = ui;

  // Cash-flow semantics.
  static const income = Color(0xFF5EEA9A);
  static const cashIn = income;
  static const expense = Color(0xFFFF5A55);
  static const cashOut = expense;
  static const saved = income;
  static const warning = Color(0xFFE8B86D);

  // Surfaces — pure black.
  static const background = Color(0xFF000000);
  static const backgroundElevated = Color(0xFF111111);
  static const surface = Color(0x12FFFFFF);
  static const surfaceHigh = Color(0x20FFFFFF);
  static const surfaceMuted = Color(0x08FFFFFF);

  // Text — cool white/grey.
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xB3FFFFFF);
  static const textOnPrimary = Color(0xFF000000);
  static const textMuted = Color(0x80FFFFFF);
  static const textDim = Color(0x59FFFFFF);

  // Lines & shadows.
  static const border = Color(0x22FFFFFF);
  static const borderLight = Color(0x38FFFFFF);
  static const shadow = Color(0xCC000000);

  // Frosty glass — white translucent panels on black.
  static const glassFill = Color(0x12FFFFFF);
  static const glassFillStrong = Color(0x1CFFFFFF);
  static const glassFillDeep = Color(0x0AFFFFFF);
  static const glassBorder = Color(0x30FFFFFF);
  static const glassHighlight = Color(0x28FFFFFF);
  static const glassSpecular = Color(0x18FFFFFF);

  // Background — flat black with optional subtle grey lift.
  static const gradientStart = Color(0xFF000000);
  static const gradientMid = Color(0xFF060606);
  static const gradientEnd = Color(0xFF000000);
  static const glowSoft = Color(0xFFFFFFFF);

  static const navBar = Color(0x00000000);

  // Legacy warm tokens (unused in frosty theme — kept for asset compat).
  static const wine = brand;
  static const ashGrey = Color(0xFF8A8A8A);
  static const linen = Color(0xFFF5F5F5);
  static const glowMaroon = Color(0xFF333333);
  static const glowMaroonDeep = Color(0xFF1A1A1A);
  static const glowWine = Color(0xFF444444);
  static const glowAsh = Color(0xFF666666);
}
