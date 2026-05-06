/// Spacing scale, ported from the Stitch prototype Tailwind config.
///
/// xs/sm/md/lg/xl = 4/8/16/24/40 px. Always use these — no magic numbers
/// in widgets.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 40;

  /// Page horizontal gutter on mobile.
  static const double gutter = 24;

  /// Maximum content width on tablets/desktops.
  static const double containerMax = 1440;
}

/// Border radius scale.
class AppRadius {
  AppRadius._();

  static const double small = 4;
  static const double medium = 8;
  static const double large = 12;
  static const double pill = 9999;
}
