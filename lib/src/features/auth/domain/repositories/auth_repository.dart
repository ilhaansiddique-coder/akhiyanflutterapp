import '../entities/user.dart';

/// Auth domain contract.
///
/// All methods either return successfully or throw a `Failure` subclass
/// from `core/errors/failures.dart`. The presentation layer is allowed to
/// catch `Failure` subtypes; it must never see raw network/IO exceptions.
///
/// Implementations live in `data/repositories/`.
abstract class AuthRepository {
  /// Returns the currently signed-in user if a refresh-able session exists
  /// in secure storage. Returns `null` when there's no token or the token
  /// is rejected — never throws for "just signed out."
  Future<User?> restoreSession();

  /// Sign in with email + password. Persists access token in secure
  /// storage and returns the freshly authenticated user.
  ///
  /// Throws `AuthFailure` for 401, `ValidationFailure` for 422,
  /// `NetworkFailure` for offline, `ServerFailure` for other 4xx/5xx.
  Future<User> signIn({required String email, required String password});

  /// Best-effort sign out. Hits the API to revoke server-side, then clears
  /// the local token regardless of the API response. Never throws.
  Future<void> signOut();
}
