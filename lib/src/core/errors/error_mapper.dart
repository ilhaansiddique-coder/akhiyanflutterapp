import '../../../api/akhiyan_api.dart' as api;
import 'failures.dart';

/// Maps any thrown object from the data layer into a [Failure] subclass.
///
/// Repositories should call this in their catch blocks so the presentation
/// layer never has to type-test against [api.ApiException] / dart:io errors.
Failure mapToFailure(Object error, [StackTrace? _]) {
  if (error is Failure) return error;
  if (error is api.NetworkException) {
    return const NetworkFailure('No internet connection');
  }
  if (error is api.ApiException) {
    if (error.isUnauthorized) {
      return AuthFailure(error.message.isEmpty ? 'Not authorized' : error.message);
    }
    return ServerFailure(
      statusCode: error.statusCode,
      message: error.message,
      raw: error.raw,
    );
  }
  return UnknownFailure(error.toString());
}

/// Friendly user-facing string for any thrown error or [Failure].
///
/// Use this from screens with `ref.watch(...).when(error: (e, _) => ErrorView(message: describeError(e), ...))`.
/// Pass [fallback] for a feature-specific default ("Could not load order",
/// "Could not save product", etc.).
String describeError(Object error, {String fallback = 'Something went wrong'}) {
  final f = error is Failure ? error : mapToFailure(error);
  return switch (f) {
    NetworkFailure() => 'No internet connection',
    AuthFailure() => f.message,
    ValidationFailure() => f.message,
    ServerFailure(:final message) when message.isNotEmpty => message,
    ServerFailure() => fallback,
    CacheFailure() => fallback,
    UnknownFailure() => fallback,
  };
}
