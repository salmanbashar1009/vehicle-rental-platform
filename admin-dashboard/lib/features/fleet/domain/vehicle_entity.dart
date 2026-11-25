import 'package:equatable/equatable.dart';

import '../../../core/error/failures.dart';

/// Fleet vehicle domain entity.
class VehicleEntity extends Equatable {
  const VehicleEntity({
    required this.id,
    required this.plateNumber,
    required this.name,
    required this.category,
    required this.make,
    required this.model,
    required this.year,
    required this.seatCapacity,
    required this.luggageCapacity,
    required this.fuelType,
    required this.status,
    required this.odometerKm,
  });

  final String id;
  final String plateNumber;
  final String name;
  final String category;
  final String make;
  final String model;
  final int year;
  final int seatCapacity;
  final int luggageCapacity;
  final String fuelType;
  final String status;
  final int odometerKm;

  @override
  List<Object?> get props => [id, plateNumber, name, category, status, odometerKm];
}

/// Abstract repository contract for fleet vehicles.
abstract interface class FleetRepository {
  Future<Result<List<VehicleEntity>>> listVehicles({String? category});
  Future<Result<VehicleEntity>> createVehicle({
    required String plateNumber,
    required String name,
    required String category,
    required String make,
    required String model,
    required int year,
    required int seatCapacity,
    required String fuelType,
  });
  Future<Result<VehicleEntity>> updateStatus({required String vehicleId, required String status});
}
