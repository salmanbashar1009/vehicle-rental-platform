import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:velofleet_driver/core/error/failures.dart';
import 'package:velofleet_driver/features/assignments/domain/assignment_models.dart';

abstract class AssignmentsEvent extends Equatable {
  const AssignmentsEvent();
  @override
  List<Object?> get props => [];
}

class AssignmentsRefreshed extends AssignmentsEvent {
  const AssignmentsRefreshed();
}

class DutyStatusToggled extends AssignmentsEvent {
  const DutyStatusToggled(this.nextStatus);
  final String nextStatus;
  @override
  List<Object?> get props => [nextStatus];
}

class AssignmentAcknowledged extends AssignmentsEvent {
  const AssignmentAcknowledged(this.assignmentId);
  final String assignmentId;
  @override
  List<Object?> get props => [assignmentId];
}

class AssignmentDeclined extends AssignmentsEvent {
  const AssignmentDeclined(this.assignmentId, this.reason);
  final String assignmentId;
  final String reason;
  @override
  List<Object?> get props => [assignmentId, reason];
}

class TripMilestoneAdvanced extends AssignmentsEvent {
  const TripMilestoneAdvanced({
    required this.tripId,
    required this.assignmentId,
    required this.milestone,
    this.lat,
    this.lng,
    this.notes,
  });

  final String tripId;
  final String assignmentId;
  final String milestone;
  final double? lat;
  final double? lng;
  final String? notes;

  @override
  List<Object?> get props => [tripId, assignmentId, milestone, lat, lng, notes];
}

class AssignmentsState extends Equatable {
  const AssignmentsState({
    this.assignments = const [],
    this.dutyStatus = 'available',
    this.isLoading = false,
    this.error,
  });

  final List<DriverAssignment> assignments;
  final String dutyStatus;
  final bool isLoading;
  final String? error;

  DriverAssignment? get activeAssignment {
    for (final a in assignments) {
      if (a.trip != null && a.trip!.status != 'service_completed') return a;
    }
    return null;
  }

  AssignmentsState copyWith({
    List<DriverAssignment>? assignments,
    String? dutyStatus,
    bool? isLoading,
    String? error,
  }) => AssignmentsState(
    assignments: assignments ?? this.assignments,
    dutyStatus: dutyStatus ?? this.dutyStatus,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );

  @override
  List<Object?> get props => [assignments, dutyStatus, isLoading, error];
}

class AssignmentsBloc extends Bloc<AssignmentsEvent, AssignmentsState> {
  AssignmentsBloc(this._repo) : super(const AssignmentsState()) {
    on<AssignmentsRefreshed>(_onRefresh);
    on<DutyStatusToggled>(_onToggleDuty);
    on<AssignmentAcknowledged>(_onAck);
    on<AssignmentDeclined>(_onDecline);
    on<TripMilestoneAdvanced>(_onMilestone);
  }

  final DriverOperationsRepository _repo;

  Future<void> _onRefresh(AssignmentsRefreshed event, Emitter<AssignmentsState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _repo.flushOfflineActions();
      final items = await _repo.listAssignments();
      emit(state.copyWith(assignments: items, isLoading: false));
    } on AppFailure catch (f) {
      emit(state.copyWith(isLoading: false, error: f.message));
    }
  }

  Future<void> _onToggleDuty(DutyStatusToggled event, Emitter<AssignmentsState> emit) async {
    try {
      final updated = await _repo.updateAvailability(event.nextStatus);
      emit(state.copyWith(dutyStatus: updated));
    } on AppFailure catch (f) {
      emit(state.copyWith(error: f.message));
    }
  }

  Future<void> _onAck(AssignmentAcknowledged event, Emitter<AssignmentsState> emit) async {
    try {
      await _repo.acknowledge(event.assignmentId);
      add(const AssignmentsRefreshed());
    } on AppFailure catch (f) {
      emit(state.copyWith(error: f.message));
    }
  }

  Future<void> _onDecline(AssignmentDeclined event, Emitter<AssignmentsState> emit) async {
    try {
      await _repo.decline(event.assignmentId, event.reason);
      add(const AssignmentsRefreshed());
    } on AppFailure catch (f) {
      emit(state.copyWith(error: f.message));
    }
  }

  Future<void> _onMilestone(TripMilestoneAdvanced event, Emitter<AssignmentsState> emit) async {
    try {
      await _repo.advanceMilestone(
        tripId: event.tripId,
        assignmentId: event.assignmentId,
        milestone: event.milestone,
        lat: event.lat,
        lng: event.lng,
        notes: event.notes,
      );
      add(const AssignmentsRefreshed());
    } on AppFailure catch (f) {
      emit(state.copyWith(error: f.message));
    }
  }
}
