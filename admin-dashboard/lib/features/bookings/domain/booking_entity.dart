import 'package:equatable/equatable.dart';

import '../../../core/error/failures.dart';

/// Booking summary and detail domain entity.
class AdminBookingEntity extends Equatable {
  const AdminBookingEntity({
    required this.id,
    required this.reference,
    required this.status,
    required this.pickupAt,
    required this.expectedEndAt,
    required this.passengerCount,
    required this.luggageCount,
    required this.pickupAddress,
    required this.destinationAddress,
    this.preferredVehicleId,
    this.specialInstructions,
    this.internalNotes,
  });

  final String id;
  final String reference;
  final String status;
  final DateTime pickupAt;
  final DateTime expectedEndAt;
  final int passengerCount;
  final int luggageCount;
  final String pickupAddress;
  final String destinationAddress;
  final String? preferredVehicleId;
  final String? specialInstructions;
  final String? internalNotes;

  @override
  List<Object?> get props => [id, reference, status, pickupAt, expectedEndAt];
}

/// Abstract repository contract for booking management.
abstract interface class AdminBookingRepository {
  Future<Result<List<AdminBookingEntity>>> listBookings({
    int page = 1,
    String? status,
    String? search,
  });

  Future<Result<AdminBookingEntity>> confirmBooking({
    required String bookingId,
    String? reason,
  });

  Future<Result<AdminBookingEntity>> cancelBooking({
    required String bookingId,
    required String reason,
  });

  Future<Result<void>> sendQuotation({
    required String bookingId,
    required String label,
    required int amountMinor,
    required int depositMinor,
    required String currency,
    required DateTime validUntil,
  });
}
