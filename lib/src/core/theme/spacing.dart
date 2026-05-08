/// Spacing + radius scales — kept aligned with the web project's
/// `--radius-*` and Tailwind spacing classes so a card's corner curve
/// looks identical on phone and web.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 40;

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
