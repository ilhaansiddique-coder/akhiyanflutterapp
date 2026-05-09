import 'package:akhiyan_admin/src/core/api/api_providers.dart';
import 'package:akhiyan_admin/src/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:akhiyan_admin/src/features/auth/domain/entities/user.dart';
import 'package:akhiyan_admin/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wires the auth domain into Riverpod.
///
/// `authControllerProvider` exposes a [User]? — null = signed out, non-null
/// = signed in. The router redirect listens to this for auth-gating.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(akhiyanApiProvider));
});

class AuthController extends Notifier<User?> {
  @override
  User? build() {
    _restore();
    return null;
  }

  Future<void> _restore() async {
    final repo = ref.read(authRepositoryProvider);
    state = await repo.restoreSession();
  }

  /// Throws a `Failure` subclass on error (see `core/errors/failures.dart`).
  /// The login screen catches and renders it via `describeError`.
  Future<void> signIn({required String email, required String password}) async {
    if (email.isEmpty || password.isEmpty) {
      throw ArgumentError('Email and password are required');
    }
    final repo = ref.read(authRepositoryProvider);
    state = await repo.signIn(email: email, password: password);
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = null;
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, User?>(AuthController.new);
