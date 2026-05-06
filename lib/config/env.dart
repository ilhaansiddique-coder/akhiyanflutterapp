/// Environment configuration for API endpoints.
///
/// Use --dart-define to set API_URL at build/run time:
///
/// Local development (web on port 61346):
///   flutter run -d chrome --dart-define=API_URL=http://localhost:3000/api/v1
///
/// Local development (Android emulator):
///   flutter run --dart-define=API_URL=http://10.0.2.2:3000/api/v1
///
/// Local development (physical phone on same network):
///   flutter run --dart-define=API_URL=http://192.168.1.100:3000/api/v1
///
/// Production:
///   flutter build apk --dart-define=API_URL=https://akhiyanbd.com/api/v1
///   flutter build ios --dart-define=API_URL=https://akhiyanbd.com/api/v1
library;

class Env {
  /// API base URL from build-time environment variable.
  /// Defaults to localhost for web/desktop development.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:3000/api/v1',
  );

  /// Whether running in production mode.
  static bool get isProduction => apiBaseUrl.contains('akhiyanbd.com');

  /// Get full URL for an endpoint.
  ///
  /// Example: Env.getUrl('/products') → 'http://localhost:3000/api/v1/products'
  static String getUrl(String endpoint) {
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return '$apiBaseUrl$cleanEndpoint';
  }
}
