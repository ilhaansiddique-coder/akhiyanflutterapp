import '../../../../../api/akhiyan_api.dart' as api;
import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Concrete implementation backed by the existing monolithic [api.AkhiyanApi].
///
/// Once `lib/api/akhiyan_api.dart` is split into per-feature data sources,
/// this class will take an `AuthRemoteDataSource` instead — but only the
/// constructor changes. The contract above the boundary stays stable.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._api);

  final api.AkhiyanApi _api;

  /// DTO → entity mapper. Kept private to the data layer so the domain
  /// never sees [api.AdminUser].
  User _toEntity(api.AdminUser u) => User(
        id: u.id,
        name: u.name,
        role: u.role,
        email: u.email,
        phone: u.phone,
        avatarUrl: u.avatar,
      );

  @override
  Future<User?> restoreSession() async {
    if (!await _api.isLoggedIn) return null;
    try {
      final dto = await _api.auth.me();
      return _toEntity(dto);
    } on Exception catch (_) {
      // Token expired/revoked/user deleted — silently clear so a fresh
      // login can run cleanly. Caller treats null as "signed out."
      await _api.storage.clear();
      return null;
    }
  }

  @override
  Future<User> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final dto = await _api.auth.login(email, password);
      return _toEntity(dto);
    } on Exception catch (e, st) {
      throw mapToFailure(e, st);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _api.auth.logout();
    } on Exception catch (_) {
      // Best-effort: even if revoke fails, drop the local token below.
    }
    // `auth.logout()` already clears storage internally, but call again
    // defensively in case it short-circuited before reaching the clear.
    try {
      await _api.storage.clear();
    } on Exception catch (_) {
      // Storage failures here are non-fatal — re-login will overwrite.
    }
  }
}
