/// Environment configuration for API endpoints.
///
/// The Flutter admin app talks to the backend's mobile namespace at
/// `/api/v1/m/*`. That namespace exposes the same resources as the dashboard
/// admin routes but with camelCase keys + a `{ data, pagination? }` envelope
/// the Dart fromJson decoders expect. SSE lives at `/api/v1/m/sync/stream`
/// (re-exported from `/api/v1/sync/stream`) so all live traffic stays under
/// the same prefix.
///
/// Override at build/run time using --dart-define:
///
///   # Local web (Chrome)
///   flutter run -d chrome --dart-define=API_URL=http://localhost:3000/api/v1/m
///
///   # Android emulator (10.0.2.2 → host's localhost)
///   flutter run --dart-define=API_URL=http://10.0.2.2:3000/api/v1/m
///
///   # Physical phone on same Wi-Fi (replace IP with your PC's LAN address)
///   flutter run --dart-define=API_URL=http://192.168.1.100:3000/api/v1/m
///
///   # Production (Coolify on Digital Ocean — current default)
///   flutter build apk --dart-define=API_URL=http://l10yo20jq5mhrg8b8nmp68cr.168.144.126.233.sslip.io/api/v1/m
///
///   # Production (custom domain — when DNS is wired)
///   flutter build apk --dart-define=API_URL=https://akhiyanbd.com/api/v1/m
library;

class Env {
  /// API base URL from build-time environment variable. Default points at
  /// the Coolify-hosted backend on Digital Ocean. Override with --dart-define
  /// to target localhost for dev, an emulator host, or a different domain.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://l10yo20jq5mhrg8b8nmp68cr.168.144.126.233.sslip.io/api/v1/m',
  );

  /// Optional tenant slug for the future SaaS migration. Sent as
  /// `X-Tenant-Slug` header on every request. Default empty (single-tenant
  /// today) — the backend ignores the header until the multi-tenant routing
  /// lands. Override per-build when needed:
  ///
  ///   flutter run --dart-define=TENANT_SLUG=akhiyanbd
  static const String tenantSlug = String.fromEnvironment('TENANT_SLUG');
}
