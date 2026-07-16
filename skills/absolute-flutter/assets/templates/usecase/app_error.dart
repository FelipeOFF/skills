import 'package:equatable/equatable.dart';

/// Sealed domain error type. Every `Left` crossing the domain boundary is one
/// of these four variants — the UI never sees a raw exception. The mapping from
/// transport errors to these variants lives in ONE place:
/// `DioException.asAppError()` (see `dio_error_mapper.dart`).
sealed class AppError extends Equatable implements Exception {
  const AppError();
}

/// A server-returned business error (a parsed error body). Carries the HTTP
/// status [code], a human [message], and the backend [serverCode] so the UI can
/// branch on a stable code instead of the message string.
class Default extends AppError {
  final int? code;
  final String? message;
  final String? serverCode;
  final dynamic metadata;

  const Default({this.code, this.message, this.serverCode, this.metadata});

  @override
  List<Object?> get props => [code, message, serverCode];
}

/// A 401 / session-expired error. First-class so the controller ladder can
/// centrally trigger logout + navigate-to-initial on any 401 from any screen,
/// instead of every screen re-checking the status code.
class Logout extends AppError {
  const Logout();

  @override
  List<Object?> get props => [];
}

/// No connectivity. Lets the UI show an offline/retry affordance distinct from
/// a server error.
class NetworkException extends AppError {
  const NetworkException();

  @override
  List<Object?> get props => [];
}

/// Catch-all for anything not classified above (a non-Dio throw, an unparseable
/// body). Carries the original [exception] for logging/diagnostics.
class UnknownException extends AppError {
  final dynamic exception;

  const UnknownException({this.exception});

  @override
  List<Object?> get props => [exception];
}
