import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../api/akhiyan_api.dart';

/// Production-grade [TokenStorage] implementation backed by
/// `flutter_secure_storage` — uses Keychain on iOS, EncryptedSharedPreferences
/// on Android. Tokens persist across app launches.
///
/// Drops the in-memory tokens used during dev so a real session survives a
/// hot restart and an actual device reboot.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessKey = 'akhiyan_access_token';

  @override
  Future<String?> getAccessToken() => _storage.read(key: _accessKey);

  @override
  Future<void> save({required String accessToken}) async {
    await _storage.write(key: _accessKey, value: accessToken);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
  }
}
