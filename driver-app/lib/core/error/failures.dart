import 'package:equatable/equatable.dart';

/// Base typed failure for domain and data boundaries.
abstract class AppFailure extends Equatable {
  const AppFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  List<Object?> get props => [message, code];
}

class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message, {super.code});
}

class AuthFailure extends AppFailure {
  const AuthFailure(super.message, {super.code});
}

class PermissionFailure extends AppFailure {
  const PermissionFailure(super.message, {super.code});
}

class ConflictFailure extends AppFailure {
  const ConflictFailure(super.message, {super.code});
}

class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message, {super.code});
}
