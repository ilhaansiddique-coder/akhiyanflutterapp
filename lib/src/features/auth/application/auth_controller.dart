import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/akhiyan_api.dart';
import '../../../core/api/api_providers.dart';

/// Light wrapper over the API's [AdminUser] so existing screens that read
/// `session.userName` / `session.userRole` keep working unchanged.
class AuthSession {
  const AuthSession({
    required this.userName,
    required this.userRole,
    this.email,
    this.phone,
    this.avatarUrl,
  });

  final String userName;
  final String userRole;
  final String? email;
  final String? phone;
  final String? avatarUrl;

  factory AuthSession.fromAdminUser(AdminUser u) => AuthSession(
        userName: u.name,
        userRole: u.role,
        email: u.email,
        phone: u.phone,
        avatarUrl: u.avatar,
      );
}

/// Auth state for the Akhiyan Admin app.
///
/// - `null` means signed out.
/// - On app start [build] kicks off a background restore: if a refresh token
///   is in [SecureTokenStorage], we hit `/auth/me` and recover the session
///   without forcing a re-login. Failing that, we silently clear stale tokens.
/// - [login] calls the real API, stores tokens, and updates state.
/// - [logout] best-effort hits the API, clears tokens, and resets state.
class AuthController extends Notifier<AuthSession?> {
  @override
  AuthSession? build() {
    _tryRestore();
    return null;
  }

  Future<void> _tryRestore() async {
    final api = ref.read(akhiyanApiProvider);
    if (!await api.isLoggedIn) return;
    try {
      final user = await api.auth.me();
      state = AuthSession.fromAdminUser(user);
    } catch (_) {
      // Token expired / revoked / user deleted — discard so login can run cleanly.
      await api.storage.clear();
    }
  }

  /// Calls `POST /auth/login`. Throws [ApiException] (401 = invalid creds,
  /// 422 = validation, etc.) or [NetworkException] (no internet). The login
  /// screen catches these and renders user-friendly messages.
  Future<void> login({required String email, required String password}) async {
    if (email.isEmpty || password.isEmpty) {
      throw ArgumentError('Email and password are required');
    }
    final api = ref.read(akhiyanApiProvider);
    final user = await api.auth.login(email, password);
    state = AuthSession.fromAdminUser(user);
  }

  Future<void> logout() async {
    final api = ref.read(akhiyanApiProvider);
    try {
      await api.auth.logout();
    } catch (_) {
      // Logout is best-effort — even if the network call fails, drop local tokens.
    }
    state = null;
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthSession?>(AuthController.new);
