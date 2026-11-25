import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failures.dart';
import '../../bookings/presentation/booking_bloc.dart';
import '../domain/vehicle_entity.dart';

sealed class FleetEvent extends Equatable {
  const FleetEvent();
  @override
  List<Object?> get props => [];
}

final class FleetFetchRequested extends FleetEvent {
  const FleetFetchRequested();
}

final class FleetCreateRequested extends FleetEvent {
  const FleetCreateRequested({
    required this.plateNumber,
    required this.name,
    required this.category,
    required this.make,
    required this.model,
    required this.year,
    required this.seatCapacity,
    required this.fuelType,
  });
  final String plateNumber;
  final String name;
  final String category;
  final String make;
  final String model;
  final int year;
  final int seatCapacity;
  final String fuelType;
  @override
  List<Object?> get props => [plateNumber, name, category, make, model, year, seatCapacity, fuelType];
}

final class FleetStatusUpdated extends FleetEvent {
  const FleetStatusUpdated({required this.vehicleId, required this.status});
  final String vehicleId;
  final String status;
  @override
  List<Object?> get props => [vehicleId, status];
}

class FleetState extends Equatable {
  const FleetState({
    this.viewStatus = ViewStatus.initial,
    this.items = const [],
    this.loadFailure,
    this.actionFailure,
  });
  final ViewStatus viewStatus;
  final List<VehicleEntity> items;
  final Failure? loadFailure;
  final Failure? actionFailure;

  @override
  List<Object?> get props => [viewStatus, items, loadFailure, actionFailure];
}

/// Manages Fleet Vehicles state.
class FleetBloc extends Bloc<FleetEvent, FleetState> {
  FleetBloc(this._repo) : super(const FleetState()) {
    on<FleetFetchRequested>(_onFetch);
    on<FleetCreateRequested>(_onCreate);
    on<FleetStatusUpdated>(_onUpdateStatus);
  }
  final FleetRepository _repo;

  Future<void> _onFetch(FleetFetchRequested _, Emitter<FleetState> emit) async {
    emit(FleetState(viewStatus: ViewStatus.loading, items: state.items));
    final res = await _repo.listVehicles();
    res.when(
      ok: (list) => emit(FleetState(
        viewStatus: list.isEmpty ? ViewStatus.empty : ViewStatus.loaded,
        items: list,
      )),
      err: (f) => emit(FleetState(viewStatus: ViewStatus.failure, loadFailure: f)),
    );
  }

  Future<void> _onCreate(FleetCreateRequested e, Emitter<FleetState> emit) async {
    final res = await _repo.createVehicle(
      plateNumber: e.plateNumber,
      name: e.name,
      category: e.category,
      make: e.make,
      model: e.model,
      year: e.year,
      seatCapacity: e.seatCapacity,
      fuelType: e.fuelType,
    );
    res.when(
      ok: (_) => add(const FleetFetchRequested()),
      err: (f) => emit(FleetState(viewStatus: state.viewStatus, items: state.items, actionFailure: f)),
    );
  }

  Future<void> _onUpdateStatus(FleetStatusUpdated e, Emitter<FleetState> emit) async {
    final res = await _repo.updateStatus(vehicleId: e.vehicleId, status: e.status);
    res.when(
      ok: (_) => add(const FleetFetchRequested()),
      err: (f) => emit(FleetState(viewStatus: state.viewStatus, items: state.items, actionFailure: f)),
    );
  }
}
