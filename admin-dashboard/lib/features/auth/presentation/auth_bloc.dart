import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failures.dart';
import '../domain/auth_entities.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

final class AuthRestoreRequested extends AuthEvent {
  const AuthRestoreRequested();
}

final class AuthLoginSubmitted extends AuthEvent {
  const AuthLoginSubmitted({required this.identifier, required this.password, this.totpCode});
  final String identifier;
  final String password;
  final String? totpCode;

  @override
  List<Object?> get props => [identifier, password, totpCode];
}

final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

sealed class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

final class AuthChecking extends AuthState {
  const AuthChecking();
}

final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.failure});
  final Failure? failure;
  @override
  List<Object?> get props => [failure];
}

final class AuthSubmitting extends AuthState {
  const AuthSubmitting();
}

final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final StaffUser user;
  @override
  List<Object?> get props => [user];
}

/// Manages staff authentication lifecycle and RBAC context.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._repo) : super(const AuthChecking()) {
    on<AuthRestoreRequested>(_onRestore);
    on<AuthLoginSubmitted>(_onLogin);
    on<AuthLogoutRequested>(_onLogout);
  }

  final AuthRepository _repo;

  Future<void> _onRestore(AuthRestoreRequested _, Emitter<AuthState> emit) async {
    final res = await _repo.restoreSession();
    res.when(
      ok: (user) => emit(user == null ? const AuthUnauthenticated() : AuthAuthenticated(user)),
      err: (_) => emit(const AuthUnauthenticated()),
    );
  }

  Future<void> _onLogin(AuthLoginSubmitted event, Emitter<AuthState> emit) async {
    emit(const AuthSubmitting());
    final res = await _repo.login(
      identifier: event.identifier,
      password: event.password,
      totpCode: event.totpCode,
    );
    res.when(
      ok: (user) => emit(AuthAuthenticated(user)),
      err: (f) => emit(AuthUnauthenticated(failure: f)),
    );
  }

  Future<void> _onLogout(AuthLogoutRequested _, Emitter<AuthState> emit) async {
    await _repo.logout();
    emit(const AuthUnauthenticated());
  }
}
