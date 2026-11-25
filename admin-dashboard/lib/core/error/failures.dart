import 'package:equatable/equatable.dart';

/// Typed domain failure hierarchy mapped from API, network, or validation errors.
sealed class Failure extends Equatable {
  const Failure({required this.message, this.code = 'ERROR', this.correlationId});

  final String message;
  final String code;
  final String? correlationId;

  @override
  List<Object?> get props => [message, code, correlationId];
}

final class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'Network connection failed.', super.code = 'NETWORK_ERROR'});
}

final class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.code = 'UNAUTHORIZED', super.correlationId});
}

final class ForbiddenFailure extends Failure {
  const ForbiddenFailure({required super.message, super.code = 'FORBIDDEN', super.correlationId});
}

final class ConflictFailure extends Failure {
  const ConflictFailure({required super.message, super.code = 'RESOURCE_CONFLICT', super.correlationId});
}

final class ValidationFailure extends Failure {
  const ValidationFailure({required super.message, super.code = 'VALIDATION_ERROR', super.correlationId});
}

final class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.code = 'SERVER_ERROR', super.correlationId});
}

/// Lightweight typed Result union avoiding external functional dependencies.
sealed class Result<T> {
  const Result();
  bool get isSuccess => this is Success<T>;
  R when<R>({required R Function(T data) ok, required R Function(Failure failure) err});
}

final class Success<T> extends Result<T> {
  const Success(this.data);
  final T data;

  @override
  R when<R>({required R Function(T data) ok, required R Function(Failure failure) err}) => ok(data);
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;

  @override
  R when<R>({required R Function(T data) ok, required R Function(Failure failure) err}) => err(failure);
}
