import 'package:flutter/material.dart';

/// Vintage Hearth palette — dark wine edition.
///
/// A deep, warm red-black base with a confident wine-red accent pushed to the
/// foreground. Ash grey and linen stay as cool/warm neutrals so the red reads
/// rich and premium without feeling flat.
abstract final class AppColors {
  // Core palette
  static const wine = Color(0xFF7A2420);
  static const ashGrey = Color(0xFFADBDAB);
  static const linen = Color(0xFFF0E5DE);

  // Base surfaces — warm red near-black.
  static const background = Color(0xFF160A0A);
  static const backgroundElevated = Color(0xFF210E0E);
  static const surface = Color(0x0DFFFFFF);
  static const surfaceHigh = Color(0x1AFFFFFF);
  static const surfaceMuted = Color(0x08FFFFFF);

  // Brand accent — a fuller, more saturated red.
  static const primary = Color(0xFFD9453F);
  static const primaryDim = Color(0xFFA8322D);
  static const primaryGlow = Color(0xFFF26A64);

  static const accent = primary;

  // Status colours.
  static const income = Color(0xFF5FB98C);
  static const saved = Color(0xFF7FA0A8);
  static const expense = Color(0xFFE0726C);
  static const warning = Color(0xFFD9A152);

  // Text — warm linen neutrals on the dark wine base.
  static const textPrimary = Color(0xFFF5ECEA);
  static const textSecondary = Color(0xFFD2C4C1);
  static const textOnPrimary = Color(0xFFFFFFFF);
  static const textMuted = Color(0xFFA1908C);
  static const textDim = Color(0xFF73625F);

  // Lines & shadows.
  static const border = Color(0x1FFFFFFF);
  static const borderLight = Color(0x33FFFFFF);
  static const shadow = Color(0x80000000);

  // Glass surfaces — translucent over the dark wine ambience.
  static const glassFill = Color(0x0FFFFFFF);
  static const glassFillStrong = Color(0x1FFFFFFF);
  static const glassBorder = Color(0x38FFFFFF);
  static const glassHighlight = Color(0x26FFFFFF);

  // Ambient wine glow blobs (background).
  static const glowMaroon = Color(0xFF7A1F1C);
  static const glowMaroonDeep = Color(0xFF4A1110);
  static const glowWine = Color(0xFF9B2D29);
  static const glowAsh = Color(0xFFADBDAB);

  static const gradientStart = Color(0xFF2C100E);
  static const gradientMid = Color(0xFF1A0B0A);
  static const gradientEnd = Color(0xFF110707);

  static const navBar = Color(0x00000000);
}
