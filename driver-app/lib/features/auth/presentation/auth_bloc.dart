import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:velofleet_driver/core/error/failures.dart';
import 'package:velofleet_driver/features/auth/domain/auth_models.dart';

abstract class DriverAuthEvent extends Equatable {
  const DriverAuthEvent();
  @override
  List<Object?> get props => [];
}

class DriverAuthStarted extends DriverAuthEvent {
  const DriverAuthStarted();
}

class DriverLoginSubmitted extends DriverAuthEvent {
  const DriverLoginSubmitted({required this.identifier, required this.password});
  final String identifier;
  final String password;
  @override
  List<Object?> get props => [identifier, password];
}

class DriverLogoutRequested extends DriverAuthEvent {
  const DriverLogoutRequested();
}

abstract class DriverAuthState extends Equatable {
  const DriverAuthState();
  @override
  List<Object?> get props => [];
}

class DriverAuthInitial extends DriverAuthState {
  const DriverAuthInitial();
}

class DriverAuthLoading extends DriverAuthState {
  const DriverAuthLoading();
}

class DriverAuthenticated extends DriverAuthState {
  const DriverAuthenticated(this.session);
  final DriverSession session;
  @override
  List<Object?> get props => [session];
}

class DriverUnauthenticated extends DriverAuthState {
  const DriverUnauthenticated([this.errorMessage]);
  final String? errorMessage;
  @override
  List<Object?> get props => [errorMessage];
}

class DriverAuthBloc extends Bloc<DriverAuthEvent, DriverAuthState> {
  DriverAuthBloc(this._repo) : super(const DriverAuthInitial()) {
    on<DriverAuthStarted>(_onStart);
    on<DriverLoginSubmitted>(_onLogin);
    on<DriverLogoutRequested>(_onLogout);
  }

  final DriverAuthRepository _repo;

  Future<void> _onStart(DriverAuthStarted event, Emitter<DriverAuthState> emit) async {
    emit(const DriverAuthLoading());
    final session = await _repo.restoreSession();
    if (session != null) {
      emit(DriverAuthenticated(session));
    } else {
      emit(const DriverUnauthenticated());
    }
  }

  Future<void> _onLogin(DriverLoginSubmitted event, Emitter<DriverAuthState> emit) async {
    emit(const DriverAuthLoading());
    try {
      final session = await _repo.login(identifier: event.identifier, password: event.password);
      emit(DriverAuthenticated(session));
    } on AppFailure catch (f) {
      emit(DriverUnauthenticated(f.message));
    } catch (e) {
      emit(DriverUnauthenticated(e.toString()));
    }
  }

  Future<void> _onLogout(DriverLogoutRequested event, Emitter<DriverAuthState> emit) async {
    await _repo.logout();
    emit(const DriverUnauthenticated());
  }
}
