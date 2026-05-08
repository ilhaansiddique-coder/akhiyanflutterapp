import 'package:akhiyan_admin/config/env.dart';

/// Resolves the API base URL based on Env configuration.
///
/// **Override at build/run time using --dart-define:**
///
/// ```bash
/// # Local web development
/// flutter run -d chrome --dart-define=API_URL=http://localhost:3000/api/v1
///
/// # Local Android emulator
/// flutter run --dart-define=API_URL=http://10.0.2.2:3000/api/v1
///
/// # Physical phone (replace 192.168.1.100 with your PC's IP)
/// flutter run --dart-define=API_URL=http://192.168.1.100:3000/api/v1
///
/// # Production build
/// flutter build apk --dart-define=API_URL=https://akhiyanbd.com/api/v1
/// ```
class ApiConfig {
  ApiConfig._();

  static String get baseUrl => Env.apiBaseUrl;
}
