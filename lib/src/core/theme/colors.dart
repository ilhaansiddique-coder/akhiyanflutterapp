import 'package:flutter/material.dart';

/// Akhiyan design tokens — Material 3 palette derived from the four key colors:
/// Primary `#8069BF` (purple), Secondary `#7C7296` (muted purple-gray),
/// Tertiary `#C9A74D` (gold), Neutral `#79767D`.
///
/// Tonal containers and on-colors are derived following M3 conventions.
/// Status accents (warning/info/success) keep their semantic hues so a green
/// "Delivered" pill still reads as success regardless of brand palette.
class AppColors {
  AppColors._();

  // ─── Primary (purple) ───────────────────────────────────────────────────
  // The container/fixed pair follows the emerald-original convention:
  // `primaryContainer` is the **dark brand surface** (used as bg for hero
  // cards, icon tiles, etc.); `primaryFixed` is the **light contrast**
  // (used as the icon/text color ON that dark surface). This deliberately
  // diverges from the M3 spec — but matches every existing screen's
  // expectations (light foreground over dark brand background).
  static const Color primary = Color(0xFF8069BF);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF4F378A);
  static const Color onPrimaryContainer = Color(0xFFE5DEFF);
  static const Color primaryFixed = Color(0xFFE5DEFF);
  static const Color primaryFixedDim = Color(0xFFCBB7F4);
  static const Color onPrimaryFixed = Color(0xFF22005D);
  static const Color onPrimaryFixedVariant = Color(0xFF4F378A);
  static const Color inversePrimary = Color(0xFFCBB7F4);

  // ─── Secondary (muted purple-gray) ──────────────────────────────────────
  static const Color secondary = Color(0xFF7C7296);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFF4A4458);
  static const Color onSecondaryContainer = Color(0xFFE5DEF8);
  static const Color secondaryFixed = Color(0xFFE5DEF8);
  static const Color secondaryFixedDim = Color(0xFFC8BFDB);
  static const Color onSecondaryFixed = Color(0xFF1A1735);
  static const Color onSecondaryFixedVariant = Color(0xFF4A4458);

  // ─── Tertiary (gold) ────────────────────────────────────────────────────
  // Same dark-bg / light-fg convention. Gold + white fails contrast (~2.5:1);
  // dark brown + light cream pair is ~10:1 (AAA).
  static const Color tertiary = Color(0xFFC9A74D);
  static const Color onTertiary = Color(0xFF1F1500);
  static const Color tertiaryContainer = Color(0xFF594400);
  static const Color onTertiaryContainer = Color(0xFFFFE0A0);
  static const Color tertiaryFixed = Color(0xFFFFE0A0);
  static const Color tertiaryFixedDim = Color(0xFFE7C365);
  static const Color onTertiaryFixed = Color(0xFF241A00);
  static const Color onTertiaryFixedVariant = Color(0xFF594400);

  // ─── Surface / background (neutral with cool tint) ──────────────────────
  static const Color background = Color(0xFFFEF7FF);
  static const Color onBackground = Color(0xFF1D1B20);
  static const Color surface = Color(0xFFFEF7FF);
  static const Color onSurface = Color(0xFF1D1B20);
  static const Color surfaceBright = Color(0xFFFEF7FF);
  static const Color surfaceDim = Color(0xFFDED8E0);
  static const Color surfaceVariant = Color(0xFFE7E0EB);
  static const Color onSurfaceVariant = Color(0xFF49454F);
  static const Color surfaceTint = Color(0xFF8069BF);
  static const Color inverseSurface = Color(0xFF322F35);
  static const Color inverseOnSurface = Color(0xFFF5EFF7);

  // ─── Surface containers (M3 elevation tiers) ────────────────────────────
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF7F2FA);
  static const Color surfaceContainer = Color(0xFFF1ECF4);
  static const Color surfaceContainerHigh = Color(0xFFEBE6EE);
  static const Color surfaceContainerHighest = Color(0xFFE6E0E9);

  // ─── Outline (from neutral #79767D) ─────────────────────────────────────
  static const Color outline = Color(0xFF79767D);
  static const Color outlineVariant = Color(0xFFCAC4D0);

  /// Hairline border used on elevated cards (lighter than `outlineVariant`,
  /// matches Tailwind `gray-100`). Use when a card should feel softer than the
  /// M3 default — particularly when paired with a real shadow.
  static const Color borderSubtle = Color(0xFFF3F4F6);

  // ─── Error (M3 standard) ────────────────────────────────────────────────
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  // ─── Status accents (semantic — kept distinct from brand) ───────────────
  static const Color warning = Color(0xFFD97706);
  static const Color warningContainer = Color(0xFFFEF3C7);
  static const Color onWarningContainer = Color(0xFF92400E);
  static const Color info = Color(0xFF1D4ED8);
  static const Color infoContainer = Color(0xFFDBEAFE);
  static const Color onInfoContainer = Color(0xFF1E40AF);
  static const Color success = Color(0xFF059669);
  static const Color successContainer = Color(0xFFD1FAE5);
  static const Color onSuccessContainer = Color(0xFF065F46);
}
