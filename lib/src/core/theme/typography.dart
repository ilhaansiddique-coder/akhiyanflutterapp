import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:flutter/material.dart';

/// Typography ported from the Stitch prototype.
///
/// All fonts are **bundled locally** in `assets/fonts/` and declared in
/// `pubspec.yaml`. No runtime network fetch — there is no `google_fonts`
/// dependency and the live theme no longer pulls font names from the
/// backend. This mirrors the web's `globals.css`, where the font stack
/// is also fixed (BanglaDigits + Hind Siliguri / Bricolage Grotesque).
///
/// Font stack:
/// - `BricolageGrotesque` (500, 700) → headings (h1, h2, h3).
/// - `HindSiliguri` (300, 400, 500, 600, 700) → body text. Bengali + Latin.
/// - `BanglaDigits` (400, 700) → **fallback only**. The TTFs are subsetted
///   upstream to Bengali digits `০–৯` + the Taka symbol `৳`. Listed first in
///   `fontFamilyFallback` so glyph lookup hits BanglaDigits for those
///   characters and falls through to HindSiliguri/Bricolage for everything
///   else (Flutter does per-glyph fallback the same way browsers do).
///
/// **Call from widget code via the [AppTextStyleX] extension on
/// BuildContext** (e.g. `context.bodyMd`). The static getters below remain
/// available for `app_theme.dart` (which builds the static fallback
/// ThemeData) and a handful of context-less call sites (CustomPainter,
/// helper functions). Both paths produce the same styles.
class AppTypography {
  AppTypography._();

  // ─── Family constants ──────────────────────────────────────────────────
  // Names match the `family:` keys in pubspec.yaml. Changing one here
  // requires updating both files.
  static const String _heading = 'BricolageGrotesque';
  static const String _body = 'HindSiliguri';
  static const String _bnDigits = 'BanglaDigits';

  /// Glyph fallback chain for body text. BanglaDigits FIRST so the
  /// subsetted Bengali digits + ৳ get picked up; HindSiliguri provides
  /// everything else.
  static const List<String> _bodyFallback = <String>[_bnDigits];

  /// Glyph fallback chain for headings. Same logic — BanglaDigits first
  /// for digits/Taka, then Bricolage handles Latin and Hind Siliguri picks
  /// up Bengali letters that Bricolage doesn't ship.
  static const List<String> _headingFallback = <String>[_bnDigits, _body];

  // ─── Headings ──────────────────────────────────────────────────────────
  static const TextStyle h1 = TextStyle(
    fontFamily: _heading,
    fontFamilyFallback: _headingFallback,
    fontSize: 40,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: AppColors.onSurface,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: _heading,
    fontFamilyFallback: _headingFallback,
    fontSize: 32,
    height: 1.3,
    fontWeight: FontWeight.w600, // Bricolage 500 is the closest weight ship
    color: AppColors.onSurface,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: _heading,
    fontFamilyFallback: _headingFallback,
    fontSize: 24,
    height: 1.4,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurface,
  );

  // ─── Body ──────────────────────────────────────────────────────────────
  // Line-heights tightened from 1.6 → 1.5 (and 1.5 → 1.4 for bodySm) when
  // we switched from runtime-streamed Google Fonts WOFF2 to bundled TTFs.
  // The bundled HindSiliguri files ship slightly taller vertical metrics
  // and the 1.6 multiplier was overflowing fixed-height card layouts by
  // ~2px. 1.5 is also the more conventional UI line-height ratio.
  static const TextStyle bodyLg = TextStyle(
    fontFamily: _body,
    fontFamilyFallback: _bodyFallback,
    fontSize: 18,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurface,
  );

  static const TextStyle bodyMd = TextStyle(
    fontFamily: _body,
    fontFamilyFallback: _bodyFallback,
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurface,
  );

  static const TextStyle bodySm = TextStyle(
    fontFamily: _body,
    fontFamilyFallback: _bodyFallback,
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurface,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _body,
    fontFamilyFallback: _bodyFallback,
    fontSize: 12,
    height: 1.4,
    letterSpacing: 0.24, // 0.02em on 12px ≈ 0.24
    fontWeight: FontWeight.w500,
    color: AppColors.onSurfaceVariant,
  );

  // ─── Data display ──────────────────────────────────────────────────────
  // Numeric / data display kept for backward compatibility. With the new
  // BanglaDigits fallback chain, the body styles already render Bengali
  // digits natively, so these are increasingly redundant — but call sites
  // still reference them. Aliased to bodyMd shape with bold weight.
  static const TextStyle dataDisplay = TextStyle(
    fontFamily: _body,
    fontFamilyFallback: _bodyFallback,
    fontSize: 16,
    height: 1,
    fontWeight: FontWeight.w500,
    color: AppColors.onSurface,
  );

  static const TextStyle dataDisplayLg = TextStyle(
    fontFamily: _body,
    fontFamilyFallback: _bodyFallback,
    fontSize: 32,
    height: 1,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
  );

  /// Builds a Material 3 [TextTheme] from our scale.
  /// Maps semantic styles to Flutter's text-theme slots so widgets that
  /// pull from `Theme.of(context).textTheme` get the right look automatically.
  static TextTheme get textTheme => const TextTheme(
        displayLarge: h1,
        displayMedium: h2,
        displaySmall: h3,
        headlineLarge: h1,
        headlineMedium: h2,
        headlineSmall: h3,
        titleLarge: h3,
        titleMedium: TextStyle(
          fontFamily: _heading,
          fontFamilyFallback: _headingFallback,
          fontSize: 18,
          height: 1.4,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
        titleSmall: TextStyle(
          fontFamily: _heading,
          fontFamilyFallback: _headingFallback,
          fontSize: 14,
          height: 1.4,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
        bodyLarge: bodyLg,
        bodyMedium: bodyMd,
        bodySmall: bodySm,
        labelLarge: TextStyle(
          fontFamily: _body,
          fontFamilyFallback: _bodyFallback,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
        labelMedium: TextStyle(
          fontFamily: _body,
          fontFamilyFallback: _bodyFallback,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
        labelSmall: caption,
      );
}

/// Live-theme aware text styles.
///
/// Reads the matching slot from `Theme.of(context).textTheme`. Since the
/// font family is now bundled and fixed (no backend customizer), these
/// effectively return the same styles as the static [AppTypography]
/// getters — but going through `Theme.of` lets us still respect any
/// runtime overrides (e.g. Material default text-scale, future a11y).
///
/// Call as `context.bodyMd`, `context.h1`, etc. Use `.copyWith(...)` exactly
/// like you used to with `AppTypography.bodyMd.copyWith(...)`.
extension AppTextStyleX on BuildContext {
  TextTheme get _tt => Theme.of(this).textTheme;

  TextStyle get h1 => _tt.displayLarge ?? AppTypography.h1;
  TextStyle get h2 => _tt.displayMedium ?? AppTypography.h2;
  TextStyle get h3 => _tt.displaySmall ?? AppTypography.h3;
  TextStyle get bodyLg => _tt.bodyLarge ?? AppTypography.bodyLg;
  TextStyle get bodyMd => _tt.bodyMedium ?? AppTypography.bodyMd;
  TextStyle get bodySm => _tt.bodySmall ?? AppTypography.bodySm;
  TextStyle get caption => _tt.labelSmall ?? AppTypography.caption;
}
