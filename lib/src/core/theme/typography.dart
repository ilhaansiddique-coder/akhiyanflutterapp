import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

/// Typography ported from the Stitch prototype.
///
/// - Bricolage Grotesque → headings (h1, h2, h3)
/// - Hind Siliguri → body text (Bangla-capable, ships with EN now, BN later)
/// - Anek Bangla → numeric / data display (digits feel native in BN later)
///
/// Fonts are pulled from Google Fonts at runtime via `google_fonts`. To
/// bundle them locally for offline-first, drop TTF files in `assets/fonts/`
/// and switch to `TextStyle(fontFamily: ...)`.
class AppTypography {
  AppTypography._();

  // Headings
  static TextStyle h1 = GoogleFonts.bricolageGrotesque(
    fontSize: 40,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: AppColors.onSurface,
  );

  static TextStyle h2 = GoogleFonts.bricolageGrotesque(
    fontSize: 32,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurface,
  );

  static TextStyle h3 = GoogleFonts.bricolageGrotesque(
    fontSize: 24,
    height: 1.4,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurface,
  );

  // Body
  static TextStyle bodyLg = GoogleFonts.hindSiliguri(
    fontSize: 18,
    height: 1.6,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurface,
  );

  static TextStyle bodyMd = GoogleFonts.hindSiliguri(
    fontSize: 16,
    height: 1.6,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurface,
  );

  static TextStyle bodySm = GoogleFonts.hindSiliguri(
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurface,
  );

  static TextStyle caption = GoogleFonts.hindSiliguri(
    fontSize: 12,
    height: 1.4,
    letterSpacing: 0.24, // 0.02em on 12px ≈ 0.24
    fontWeight: FontWeight.w500,
    color: AppColors.onSurfaceVariant,
  );

  // Data display (numbers, IDs, currency)
  static TextStyle dataDisplay = GoogleFonts.anekBangla(
    fontSize: 16,
    height: 1.0,
    fontWeight: FontWeight.w500,
    color: AppColors.onSurface,
  );

  static TextStyle dataDisplayLg = GoogleFonts.anekBangla(
    fontSize: 32,
    height: 1.0,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
  );

  /// Builds a Material 3 [TextTheme] from our scale.
  /// Maps our semantic styles to Flutter's text-theme slots so widgets that
  /// pull from `Theme.of(context).textTheme` get the right look automatically.
  static TextTheme get textTheme => TextTheme(
        displayLarge: h1,
        displayMedium: h2,
        displaySmall: h3,
        headlineLarge: h1,
        headlineMedium: h2,
        headlineSmall: h3,
        titleLarge: h3,
        titleMedium: GoogleFonts.bricolageGrotesque(
          fontSize: 18,
          height: 1.4,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
        titleSmall: GoogleFonts.bricolageGrotesque(
          fontSize: 14,
          height: 1.4,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
        bodyLarge: bodyLg,
        bodyMedium: bodyMd,
        bodySmall: bodySm,
        labelLarge: GoogleFonts.hindSiliguri(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
        labelMedium: GoogleFonts.hindSiliguri(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
        labelSmall: caption,
      );
}
