import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failures.dart';
import '../../bookings/presentation/booking_bloc.dart';
import '../domain/dispatch_entities.dart';

sealed class DispatchEvent extends Equatable {
  const DispatchEvent();
  @override
  List<Object?> get props => [];
}

final class DispatchResourcesRequested extends DispatchEvent {
  const DispatchResourcesRequested(this.bookingId);
  final String bookingId;
  @override
  List<Object?> get props => [bookingId];
}

final class DispatchAssignSubmitted extends DispatchEvent {
  const DispatchAssignSubmitted({
    required this.bookingId,
    required this.vehicleId,
    required this.driverId,
    this.isReassignment = false,
    this.reason,
  });
  final String bookingId;
  final String vehicleId;
  final String driverId;
  final bool isReassignment;
  final String? reason;
  @override
  List<Object?> get props => [bookingId, vehicleId, driverId, isReassignment, reason];
}

class DispatchState extends Equatable {
  const DispatchState({
    this.viewStatus = ViewStatus.initial,
    this.selectedBookingId,
    this.vehicles = const [],
    this.drivers = const [],
    this.assignBusy = false,
    this.assignSuccess = false,
    this.failure,
  });

  final ViewStatus viewStatus;
  final String? selectedBookingId;
  final List<EligibleVehicle> vehicles;
  final List<EligibleDriver> drivers;
  final bool assignBusy;
  final bool assignSuccess;
  final Failure? failure;

  @override
  List<Object?> get props => [
    viewStatus,
    selectedBookingId,
    vehicles,
    drivers,
    assignBusy,
    assignSuccess,
    failure,
  ];
}

/// Manages eligible resource lookup and atomic dispatch assignment with 409 recovery.
class DispatchBloc extends Bloc<DispatchEvent, DispatchState> {
  DispatchBloc(this._repo) : super(const DispatchState()) {
    on<DispatchResourcesRequested>(_onLoad);
    on<DispatchAssignSubmitted>(_onAssign);
  }
  final DispatchRepository _repo;

  Future<void> _onLoad(DispatchResourcesRequested e, Emitter<DispatchState> emit) async {
    emit(DispatchState(viewStatus: ViewStatus.loading, selectedBookingId: e.bookingId));
    final res = await _repo.fetchEligibleResources(e.bookingId);
    res.when(
      ok: (bundle) => emit(DispatchState(
        viewStatus: (bundle.vehicles.isEmpty && bundle.drivers.isEmpty)
            ? ViewStatus.empty
            : ViewStatus.loaded,
        selectedBookingId: e.bookingId,
        vehicles: bundle.vehicles,
        drivers: bundle.drivers,
      )),
      err: (f) => emit(DispatchState(
        viewStatus: ViewStatus.failure,
        selectedBookingId: e.bookingId,
        failure: f,
      )),
    );
  }

  Future<void> _onAssign(DispatchAssignSubmitted e, Emitter<DispatchState> emit) async {
    emit(DispatchState(
      viewStatus: state.viewStatus,
      selectedBookingId: e.bookingId,
      vehicles: state.vehicles,
      drivers: state.drivers,
      assignBusy: true,
    ));
    final res = await _repo.assign(
      bookingId: e.bookingId,
      vehicleId: e.vehicleId,
      driverId: e.driverId,
      isReassignment: e.isReassignment,
      reason: e.reason,
    );
    await res.when(
      ok: (_) async => emit(DispatchState(
        viewStatus: ViewStatus.loaded,
        selectedBookingId: e.bookingId,
        vehicles: state.vehicles,
        drivers: state.drivers,
        assignSuccess: true,
      )),
      err: (f) async {
        // Refresh eligible resources so operator immediately sees updated conflicts.
        final refreshed = await _repo.fetchEligibleResources(e.bookingId);
        refreshed.when(
          ok: (bundle) => emit(DispatchState(
            viewStatus: ViewStatus.loaded,
            selectedBookingId: e.bookingId,
            vehicles: bundle.vehicles,
            drivers: bundle.drivers,
            failure: f,
          )),
          err: (_) => emit(DispatchState(
            viewStatus: state.viewStatus,
            selectedBookingId: e.bookingId,
            vehicles: state.vehicles,
            drivers: state.drivers,
            failure: f,
          )),
        );
      },
    );
  }
}
