/// Spacing + radius scales — kept aligned with the web project's
/// `--radius-*` and Tailwind spacing classes so a card's corner curve
/// looks identical on phone and web.
class AppSpacing {
  AppSpacing._();

  // Tailwind rhythm: 4 / 8 / 12 / 16 / 24 / 40 (p-1 / p-2 / p-3 / p-4 /
  // p-6 / p-10). Adding the 12px rung lets gutters and inner-card padding
  // line up with the web admin pixel-for-pixel.
  static const double xs = 4;   // p-1
  static const double sm = 8;   // p-2
  static const double s12 = 12; // p-3 — was missing; bridges sm and md
  static const double md = 16;  // p-4
  static const double lg = 24;  // p-6
  static const double xl = 40;  // p-10

  /// Page horizontal gutter on mobile.
  static const double gutter = 16;

  /// Maximum content width on tablets — matches web `--container-max`
  /// (1280px desktop). On phones the gutter caps it earlier in practice.
  static const double containerMax = 1280;
}

/// Border radius scale — matches web `--radius-sm/md/lg/xl` exactly.
///
/// xSmall is below the web scale and used only for tiny decorative chips
/// where 6px reads too curvy. Pill stays a separate concept (full circle
/// for rounded toggles / status dots).
class AppRadius {
  AppRadius._();

  /// Tighter than web's smallest — only for sub-pill chips and tiny dots.
  static const double xSmall = 4;

  static const double small = 6;     // matches web --radius-sm
  static const double medium = 12;   // matches web --radius-md
  static const double large = 16;    // matches web --radius-lg
  static const double xLarge = 24;   // matches web --radius-xl
  static const double pill = 9999;
}
