/// Domain-level error type. Surfaced to UI / controllers.
///
/// The data layer catches platform/HTTP exceptions and maps them to one of
/// these subclasses at the repository boundary. The presentation layer never
/// sees a raw `Exception` — only a [Failure].
sealed class Failure implements Exception {
  const Failure(this.message);

  final String message;

  @override
  String toString() => '$runtimeType($message)';
}

/// No connectivity, DNS failure, socket reset, TLS failure.
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Network unavailable']);
}

/// Server reachable but returned 4xx/5xx. [statusCode] and [raw] preserve
/// the wire response so screens can show structured validation errors.
class ServerFailure extends Failure {
  const ServerFailure({
    required this.statusCode,
    required String message,
    this.raw,
  }) : super(message);

  final int statusCode;
  final Object? raw;
}

/// Auth token missing / expired / rejected. The auth guard listens for this
/// and bounces the user to the login screen.
class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Not authorized']);
}

/// Local validation, field-level errors before sending.
class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {this.fieldErrors});

  final Map<String, List<String>>? fieldErrors;
}

/// Disk / SharedPreferences / SecureStorage failure.
class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Storage error']);
}

/// Catch-all for unexpected exceptions the data layer didn't classify.
class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Something went wrong']);
}
