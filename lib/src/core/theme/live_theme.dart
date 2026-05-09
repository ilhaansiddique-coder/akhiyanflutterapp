import 'package:akhiyan_admin/src/core/api/api_providers.dart';
import 'package:akhiyan_admin/src/core/sync/sync_client.dart';
import 'package:akhiyan_admin/src/core/theme/app_theme.dart';
import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Decoded payload from `GET /api/v1/m/theme`.
///
/// The backend reads the customizer (`theme.color.primary`, `theme.font.body`,
/// site_logo, etc.) from siteSettings, fills missing rows with declared
/// defaults from `theme-tokens.ts`, and reshapes into this nested tree.
@immutable
class LiveTheme {

  const LiveTheme({
    required this.colors,
    required this.fonts,
    required this.radius,
    required this.spacing,
    required this.branding,
  });

  factory LiveTheme.fromJson(Map<String, dynamic> json) {
    Map<String, String> stringMap(dynamic v) {
      if (v is! Map) return const {};
      return v.map((k, val) => MapEntry(k.toString(), (val ?? '').toString()));
    }

    Map<String, num> numMap(dynamic v) {
      if (v is! Map) return const {};
      final out = <String, num>{};
      v.forEach((k, val) {
        if (val is num) {
          out[k.toString()] = val;
        } else if (val is String) {
          final parsed = num.tryParse(val);
          if (parsed != null) out[k.toString()] = parsed;
        }
      });
      return out;
    }

    Map<String, String?> nullableStringMap(dynamic v) {
      if (v is! Map) return const {};
      return v.map((k, val) => MapEntry(k.toString(), val as String?));
    }

    return LiveTheme(
      colors: stringMap(json['colors']),
      fonts: (json['fonts'] is Map ? Map<String, dynamic>.from(json['fonts'] as Map) : <String, dynamic>{}),
      radius: numMap(json['radius']),
      spacing: numMap(json['spacing']),
      branding: nullableStringMap(json['branding']),
    );
  }
  final Map<String, String> colors;
  final Map<String, dynamic> fonts;
  final Map<String, num> radius;
  final Map<String, num> spacing;
  final Map<String, String?> branding;

  /// Convert a `#rrggbb` hex string to a Color. Falls back to [fallback] on
  /// any malformed input (defensive — the customizer can save anything).
  static Color _parseHex(String? hex, Color fallback) {
    if (hex == null) return fallback;
    final s = hex.trim().replaceFirst('#', '');
    if (s.length != 6 && s.length != 8) return fallback;
    final value = int.tryParse(s, radix: 16);
    if (value == null) return fallback;
    return s.length == 6 ? Color(0xFF000000 | value) : Color(value);
  }

  Color colorOr(String key, Color fallback) => _parseHex(colors[key], fallback);

  /// Build a [ThemeData] from this payload, layered on top of the static
  /// design defaults so any unknown keys still render correctly.
  ///
  /// **Fonts are NOT pulled from the backend.** They're bundled locally in
  /// `assets/fonts/` (BricolageGrotesque + HindSiliguri + BanglaDigits) and
  /// declared statically in `AppTypography`. The backend's `fonts.body` /
  /// `fonts.heading` choice is intentionally ignored to avoid a runtime
  /// network fetch on every theme bump and to match the web's fixed font
  /// stack.
  ///
  /// Body size scaling (`fonts.size_base`) is still honored — it applies to
  /// the existing TextTheme via `apply(fontSizeFactor: ...)` without
  /// changing the family.
  ThemeData toThemeData() {
    final base = AppTheme.light;

    final primary = colorOr('primary', AppColors.primary);
    final primaryDark = colorOr('primary_dark', AppColors.onPrimaryContainer);
    final background = colorOr('background', AppColors.background);
    final foreground = colorOr('foreground', AppColors.onSurface);
    final textBody = colorOr('text_body', AppColors.onSurface);
    final textMuted = colorOr('text_muted', AppColors.onSurfaceVariant);
    final border = colorOr('border', AppColors.outlineVariant);

    final colorScheme = base.colorScheme.copyWith(
      primary: primary,
      onPrimary: AppColors.onPrimary, // keep contrast pair stable
      primaryContainer: colorOr('primary_light', AppColors.primaryContainer),
      onPrimaryContainer: primaryDark,
      surface: background,
      onSurface: foreground,
      onSurfaceVariant: textMuted,
      outline: border.withValues(alpha: 0.7),
      outlineVariant: border,
      surfaceTint: primary,
    );

    final baseSize = (fonts['size_base'] as num?)?.toDouble() ?? 16.0;

    final textTheme = base.textTheme.apply(
      bodyColor: textBody,
      displayColor: foreground,
      fontSizeFactor: baseSize / 16.0,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      // The remaining sub-theme widgets (buttons, cards, inputs) inherit
      // from colorScheme so they pick up the new primary automatically.
    );
  }
}

/// Fetches `/api/v1/m/theme`. Re-fetches whenever the SSE `theme` channel
/// version bumps — that's the live-update hook. Cached locally via Riverpod's
/// FutureProvider keep-alive (ref.keepAlive() is implicit on family + watch).
final liveThemeProvider = FutureProvider<LiveTheme>((ref) async {
  // Re-evaluate on every theme bump. Settings bumps are intentionally NOT
  // wired here — they'd cause unnecessary refetches when admins edit
  // unrelated fields like courier API keys.
  ref.watch(syncVersionProvider('theme'));

  final api = ref.watch(akhiyanApiProvider);
  // Use the api.request helper directly — saves duplicating the auth/
  // 401-retry plumbing. The /theme endpoint is public-shaped (no auth
  // required) but going through the same client keeps headers consistent.
  final res = await api.request('GET', '/theme') as Map<String, dynamic>;
  return LiveTheme.fromJson(res);
});

/// Synchronous accessor that returns the current live ThemeData if the
/// fetch has resolved, or the static fallback while loading / on error.
/// MaterialApp.theme can read this directly without needing AsyncValue
/// pattern-matching at the root of the widget tree.
final activeThemeDataProvider = Provider<ThemeData>((ref) {
  final live = ref.watch(liveThemeProvider);
  return live.maybeWhen(
    data: (t) => t.toThemeData(),
    orElse: () => AppTheme.light,
  );
});
