import 'package:akhiyan_admin/src/core/errors/failures.dart' show Failure;

/// Data-layer exception types. These live below the repository boundary
/// and get caught + mapped to [Failure] subclasses there. Never thrown
/// across feature boundaries.
class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'AppException: $message';
}

class NetworkException extends AppException {
  const NetworkException([super.message = 'Network unavailable']);
}

class TimeoutException extends AppException {
  const TimeoutException([super.message = 'Request timed out']);
}

class ServerException extends AppException {
  const ServerException({
    required this.statusCode,
    required String message,
    this.raw,
  }) : super(message);

  final int statusCode;
  final Object? raw;
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'Unauthorized']);
}

class CacheException extends AppException {
  const CacheException([super.message = 'Cache error']);
}
