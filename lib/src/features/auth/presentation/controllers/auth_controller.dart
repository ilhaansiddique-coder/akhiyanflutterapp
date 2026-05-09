import 'package:akhiyan_admin/src/core/api/api_providers.dart';
import 'package:akhiyan_admin/src/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:akhiyan_admin/src/features/auth/domain/entities/user.dart';
import 'package:akhiyan_admin/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wires the auth domain into Riverpod.
///
/// `authControllerProvider` exposes an [AsyncValue]\<[User]?\>:
/// - `AsyncLoading` while the secure-storage token is being hydrated on
///   cold start (NEW — was previously `null` which the router mistook for
///   "logged out" and bounced the user to /login on every refresh).
/// - `AsyncData(null)` once we've confirmed the user is signed out.
/// - `AsyncData(user)` once the session restores or login succeeds.
/// - `AsyncError` only on signIn failures (caught by the login screen).
///
/// The router redirect treats the loading state as "wait, don't redirect
/// yet" so the user never flashes through /login on refresh.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(akhiyanApiProvider));
});

class AuthController extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    final repo = ref.read(authRepositoryProvider);
    return repo.restoreSession();
  }

  /// Throws a `Failure` subclass on error (see `core/errors/failures.dart`).
  /// The login screen catches and renders it via `describeError` while
  /// managing its own button-loading state — so we don't flip [state] to
  /// AsyncLoading here (a thrown signIn would otherwise leave it loading
  /// forever and trap the router redirect).
  Future<void> signIn({required String email, required String password}) async {
    if (email.isEmpty || password.isEmpty) {
      throw ArgumentError('Email and password are required');
    }
    final repo = ref.read(authRepositoryProvider);
    final user = await repo.signIn(email: email, password: password);
    state = AsyncData(user);
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(null);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, User?>(AuthController.new);
