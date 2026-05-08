import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:akhiyan_admin/api/akhiyan_api.dart';

/// Production-grade [TokenStorage] backed by `flutter_secure_storage`
/// (Keychain on iOS, EncryptedSharedPreferences on Android) with an
/// in-memory cache layered on top.
///
/// Why the cache: each `_storage.read(...)` is a platform-channel hop to
/// Keystore/Keychain, which costs 5–50ms (older Android: 80–150ms). Without
/// caching, every API call paid that tax — opening a screen with 4 parallel
/// requests wasted 40–600ms before any byte of data left the device.
///
/// The cache is filled on first read, kept in sync on `save`, and cleared
/// on `clear` (logout / 401). A new app launch starts with an empty cache
/// and pays the platform-channel cost exactly once.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessKey = 'akhiyan_access_token';

  /// In-memory token. `null` means "not yet read from disk." After the first
  /// successful read this is non-null whenever a session exists; `clear`
  /// resets it to null so a stale token can never leak post-logout.
  String? _cachedAccess;
  bool _cacheLoaded = false;

  @override
  Future<String?> getAccessToken() async {
    if (_cacheLoaded) return _cachedAccess;
    _cachedAccess = await _storage.read(key: _accessKey);
    _cacheLoaded = true;
    return _cachedAccess;
  }

  @override
  Future<void> save({required String accessToken}) async {
    await _storage.write(key: _accessKey, value: accessToken);
    _cachedAccess = accessToken;
    _cacheLoaded = true;
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    _cachedAccess = null;
    _cacheLoaded = true; // "loaded and empty" — skip the disk read next time
  }
}
