import 'package:equatable/equatable.dart';

import '../../../core/error/failures.dart';

/// Candidate vehicle returned by /dispatch/eligible-resources.
class EligibleVehicle extends Equatable {
  const EligibleVehicle({
    required this.id,
    required this.plateNumber,
    required this.name,
    required this.seatCapacity,
    required this.isEligible,
    this.conflictReason,
  });

  final String id;
  final String plateNumber;
  final String name;
  final int seatCapacity;
  final bool isEligible;
  final String? conflictReason;

  @override
  List<Object?> get props => [id, plateNumber, isEligible, conflictReason];
}

/// Candidate driver returned by /dispatch/eligible-resources.
class EligibleDriver extends Equatable {
  const EligibleDriver({
    required this.id,
    required this.fullName,
    required this.licenceNumber,
    required this.isEligible,
    this.conflictReason,
  });

  final String id;
  final String fullName;
  final String licenceNumber;
  final bool isEligible;
  final String? conflictReason;

  @override
  List<Object?> get props => [id, fullName, licenceNumber, isEligible, conflictReason];
}

class EligibleResourcesBundle {
  const EligibleResourcesBundle({required this.vehicles, required this.drivers});
  final List<EligibleVehicle> vehicles;
  final List<EligibleDriver> drivers;
}

/// Abstract repository contract for atomic dispatch allocation.
abstract interface class DispatchRepository {
  Future<Result<EligibleResourcesBundle>> fetchEligibleResources(String bookingId);
  Future<Result<void>> assign({
    required String bookingId,
    required String vehicleId,
    required String driverId,
    required bool isReassignment,
    String? reason,
  });
}
