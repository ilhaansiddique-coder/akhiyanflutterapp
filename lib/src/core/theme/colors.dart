import 'package:flutter/material.dart';

/// Akhiyan design tokens — Material 3 palette derived from the brand colors:
/// Primary `#FF5733` (orange), Secondary `#2E86AB` (blue),
/// Tertiary `#CC3300` (deep orange/red accent), Neutral grays.
///
/// Sourced from akhiyanbd.com brand palette. Tonal containers and on-colors
/// follow M3 conventions. Status accents (warning/info/success) keep their
/// semantic hues so a green "Delivered" pill still reads as success
/// regardless of brand palette.
class AppColors {
  AppColors._();

  // ─── Primary (orange) ───────────────────────────────────────────────────
  static const Color primary = Color(0xFFFF5733);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFFFE2D9);
  static const Color onPrimaryContainer = Color(0xFF7A1F0A);
  static const Color primaryFixed = Color(0xFFFFD9CC);
  static const Color primaryFixedDim = Color(0xFFFF7555);
  static const Color onPrimaryFixed = Color(0xFF5C1A09);
  static const Color onPrimaryFixedVariant = Color(0xFF7A1F0A);
  static const Color inversePrimary = Color(0xFFFF7555);

  // ─── Secondary (blue) ───────────────────────────────────────────────────
  static const Color secondary = Color(0xFF2E86AB);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFD1E7F0);
  static const Color onSecondaryContainer = Color(0xFF0E3A4F);
  static const Color secondaryFixed = Color(0xFFD1E7F0);
  static const Color secondaryFixedDim = Color(0xFFA8CFE0);
  static const Color onSecondaryFixed = Color(0xFF0E3A4F);
  static const Color onSecondaryFixedVariant = Color(0xFF1B5470);

  // ─── Tertiary (deep orange/red) ─────────────────────────────────────────
  static const Color tertiary = Color(0xFFCC3300);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFFFCFC2);
  static const Color onTertiaryContainer = Color(0xFF4A1500);
  static const Color tertiaryFixed = Color(0xFFFFCFC2);
  static const Color tertiaryFixedDim = Color(0xFFE63D1F);
  static const Color onTertiaryFixed = Color(0xFF4A1500);
  static const Color onTertiaryFixedVariant = Color(0xFF7A1F0A);

  // ─── Surface / background (neutral, near-white) ─────────────────────────
  static const Color background = Color(0xFFFFFFFF);
  static const Color onBackground = Color(0xFF1A1A1A);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF1A1A1A);
  static const Color surfaceBright = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFE8E8E8);
  static const Color surfaceVariant = Color(0xFFF7F7F7);
  static const Color onSurfaceVariant = Color(0xFF666666);
  static const Color surfaceTint = Color(0xFFFF5733);
  static const Color inverseSurface = Color(0xFF1A1A1A);
  static const Color inverseOnSurface = Color(0xFFF7F7F7);

  // ─── Surface containers (M3 elevation tiers) ────────────────────────────
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFFAFAFA);
  static const Color surfaceContainer = Color(0xFFF7F7F7);
  static const Color surfaceContainerHigh = Color(0xFFEFEFEF);
  static const Color surfaceContainerHighest = Color(0xFFE8E8E8);

  // ─── Outline ────────────────────────────────────────────────────────────
  static const Color outline = Color(0xFF888888);
  static const Color outlineVariant = Color(0xFFE8E8E8);

  /// Hairline border used on elevated cards (lighter than `outlineVariant`).
  /// Use when a card should feel softer than the M3 default — particularly
  /// when paired with a real shadow.
  static const Color borderSubtle = Color(0xFFE8E8E8);

  // ─── Error (M3 standard, kept) ──────────────────────────────────────────
  static const Color error = Color(0xFFDC2626);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFEE2E2);
  static const Color onErrorContainer = Color(0xFF7F1D1D);

  // ─── Status accents (semantic — kept distinct from brand) ───────────────
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningContainer = Color(0xFFFEF3C7);
  static const Color onWarningContainer = Color(0xFF92400E);
  static const Color info = Color(0xFF2E86AB);
  static const Color infoContainer = Color(0xFFD1E7F0);
  static const Color onInfoContainer = Color(0xFF0E3A4F);
  static const Color success = Color(0xFF16A34A);
  static const Color successContainer = Color(0xFFD1FAE5);
  static const Color onSuccessContainer = Color(0xFF065F46);
}
