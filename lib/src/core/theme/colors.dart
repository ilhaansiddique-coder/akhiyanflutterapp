import 'package:flutter/material.dart';

/// Akhiyan design tokens — kept in lock-step with the web project's CSS
/// variables in `src/app/globals.css`. When the web customizer changes a
/// color, update both files together. Live-theme bumps over SSE override
/// the static defaults at runtime.
///
/// Brand palette:
///   primary       #ea580c  Tailwind orange-600
///   primary-light #fb923c  Tailwind orange-400
///   primary-dark  #c2410c  Tailwind orange-700
///   secondary     #14b8a6  Tailwind teal-500
///   foreground    #431407  Tailwind orange-950 (darkest text)
///   background    #fffbf5  warm cream
///   border        #fed7aa  Tailwind orange-200
///
/// Material 3 container tokens derive from the primary/secondary, picked
/// from the same hue ramp (Tailwind orange/teal scales) so they sit in
/// the same family as the web equivalents and Flutter's built-in tonal
/// algorithms don't drift away.
class AppColors {
  AppColors._();

  // ─── Primary (orange) — matches web --primary ──────────────────────────
  static const Color primary = Color(0xFFEA580C);          // orange-600
  static const Color primaryLight = Color(0xFFFB923C);     // orange-400
  static const Color primaryDark = Color(0xFFC2410C);      // orange-700
  static const Color primaryDarker = Color(0xFF9A3412);    // orange-800
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFFFEDD5); // orange-100
  static const Color onPrimaryContainer = Color(0xFF7C2D12); // orange-900
  static const Color primaryFixed = Color(0xFFFFEDD5);
  static const Color primaryFixedDim = Color(0xFFFDBA74);  // orange-300
  static const Color onPrimaryFixed = Color(0xFF431407);
  static const Color onPrimaryFixedVariant = Color(0xFF7C2D12);
  static const Color inversePrimary = Color(0xFFFB923C);

  // ─── Secondary (teal) — matches web --secondary ────────────────────────
  static const Color secondary = Color(0xFF14B8A6);        // teal-500
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFCCFBF1); // teal-100
  static const Color onSecondaryContainer = Color(0xFF134E4A); // teal-900
  static const Color secondaryFixed = Color(0xFFCCFBF1);
  static const Color secondaryFixedDim = Color(0xFF5EEAD4);
  static const Color onSecondaryFixed = Color(0xFF134E4A);
  static const Color onSecondaryFixedVariant = Color(0xFF115E59); // teal-800

  // ─── Tertiary (deep orange/red accent) ─────────────────────────────────
  static const Color tertiary = Color(0xFFCC3300);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFFFCFC2);
  static const Color onTertiaryContainer = Color(0xFF4A1500);
  static const Color tertiaryFixed = Color(0xFFFFCFC2);
  static const Color tertiaryFixedDim = Color(0xFFE63D1F);
  static const Color onTertiaryFixed = Color(0xFF4A1500);
  static const Color onTertiaryFixedVariant = Color(0xFF7A1F0A);

  // ─── Background / surface — matches web --background, --background-alt ─
  /// Page background. Warm cream `#fffbf5` matches the web; on phones with
  /// edge-to-edge displays it reads softer than pure white.
  static const Color background = Color(0xFFFFFBF5);
  static const Color backgroundAlt = Color(0xFFFFF7ED);    // orange-50
  static const Color onBackground = Color(0xFF431407);     // foreground
  static const Color surface = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF1A1A1A);
  static const Color surfaceBright = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFF5F5F5);
  static const Color surfaceVariant = Color(0xFFFFF7ED);
  static const Color onSurfaceVariant = Color(0xFF666666);
  static const Color surfaceTint = primary;
  static const Color inverseSurface = Color(0xFF1A1A1A);
  static const Color inverseOnSurface = Color(0xFFF7F7F7);

  // ─── Surface containers (M3 elevation tiers) ───────────────────────────
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFFFFBF5);
  static const Color surfaceContainer = Color(0xFFFFF7ED);
  static const Color surfaceContainerHigh = Color(0xFFFFEDD5);
  static const Color surfaceContainerHighest = Color(0xFFFED7AA);

  // ─── Outline / borders — matches web --border ──────────────────────────
  static const Color outline = Color(0xFF888888);          // text-muted
  static const Color outlineVariant = Color(0xFFFED7AA);   // border
  static const Color borderSubtle = Color(0xFFE8E8E8);
  static const Color slateBorder = Color(0xFFE2E8F0);

  // ─── Text — matches web --text-body / --text-muted / --text-light ──────
  static const Color textBody = Color(0xFF404040);
  static const Color textMuted = Color(0xFF888888);
  static const Color textLight = Color(0xFFAAAAAA);
  static const Color foreground = Color(0xFF431407);       // darkest text

  // ─── Error ─────────────────────────────────────────────────────────────
  static const Color error = Color(0xFFDC2626);            // sale-red on web
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFEE2E2);
  static const Color onErrorContainer = Color(0xFF7F1D1D);

  // ─── Status accents (semantic) ─────────────────────────────────────────
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningContainer = Color(0xFFFEF3C7);
  static const Color onWarningContainer = Color(0xFF92400E);
  static const Color info = Color(0xFF14B8A6);             // matches secondary
  static const Color infoContainer = Color(0xFFCCFBF1);
  static const Color onInfoContainer = Color(0xFF134E4A);
  static const Color success = Color(0xFF14B8A6);          // badge-green
  static const Color successContainer = Color(0xFFCCFBF1);
  static const Color onSuccessContainer = Color(0xFF134E4A);

  // ─── Storefront-only accents (matches web tokens directly) ─────────────
  /// Sale price strikethrough / discount badge red. Distinct from `error`
  /// because the storefront uses the same hex for both — kept as separate
  /// names so semantic intent reads in the call site.
  static const Color saleRed = Color(0xFFDC2626);
  static const Color badgeGreen = Color(0xFF14B8A6);

  // ─── Social brand colors (matches web --facebook etc.) ─────────────────
  static const Color facebook = Color(0xFF3B5998);
  static const Color instagram = Color(0xFF8A3AB9);
  static const Color youtube = Color(0xFFCD201F);
  static const Color whatsapp = Color(0xFF25D366);
}
