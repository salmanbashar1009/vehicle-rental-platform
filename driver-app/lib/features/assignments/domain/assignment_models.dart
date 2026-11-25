import 'package:equatable/equatable.dart';

import 'package:velofleet_driver/core/widgets/stop_overview_map.dart';

/// Active-tracking privacy gate matching shared-contracts/state-machines.md.
const Set<String> activeTrackingMilestones = {
  'en_route_to_pickup',
  'arrived_at_pickup',
  'loading_started',
  'loading_completed',
  'picked_up',
  'journey_started',
  'at_destination',
  'unloading_started',
  'unloading_completed',
};

class TripModel extends Equatable {
  const TripModel({
    required this.id,
    required this.assignmentId,
    required this.status,
    this.startedAt,
    this.completedAt,
    this.endOdometer,
  });

  factory TripModel.fromJson(Map<String, dynamic> j) => TripModel(
    id: j['id'].toString(),
    assignmentId: j['assignment_id'].toString(),
    status: j['status'].toString(),
    startedAt: j['started_at'] != null ? DateTime.tryParse(j['started_at'].toString()) : null,
    completedAt: j['completed_at'] != null
        ? DateTime.tryParse(j['completed_at'].toString())
        : null,
    endOdometer: j['end_odometer'] as int?,
  );

  final String id;
  final String assignmentId;
  final String status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int? endOdometer;

  bool get isTrackingWindowOpen => activeTrackingMilestones.contains(status);

  TripModel copyWith({String? status}) => TripModel(
    id: id,
    assignmentId: assignmentId,
    status: status ?? this.status,
    startedAt: startedAt,
    completedAt: completedAt,
    endOdometer: endOdometer,
  );

  @override
  List<Object?> get props => [id, assignmentId, status, startedAt, completedAt, endOdometer];
}

class DriverAssignment extends Equatable {
  const DriverAssignment({
    required this.assignmentId,
    required this.assignmentStatus,
    required this.bookingId,
    required this.bookingReference,
    required this.serviceName,
    required this.workflowSteps,
    required this.pickupAt,
    required this.expectedEndAt,
    required this.customerName,
    required this.customerPhone,
    required this.vehicleName,
    required this.vehiclePlate,
    required this.stops,
    this.specialInstructions,
    this.trip,
  });

  factory DriverAssignment.fromJson(Map<String, dynamic> j) {
    final stopsJson = (j['stops'] as List<dynamic>?) ?? const [];
    return DriverAssignment(
      assignmentId: j['assignment_id'].toString(),
      assignmentStatus: j['assignment_status'].toString(),
      bookingId: j['booking_id'].toString(),
      bookingReference: j['booking_reference'].toString(),
      serviceName: j['service_name'].toString(),
      workflowSteps: ((j['workflow_steps'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      pickupAt: DateTime.parse(j['pickup_at'].toString()),
      expectedEndAt: DateTime.parse(j['expected_end_at'].toString()),
      customerName: j['customer_name'].toString(),
      customerPhone: j['customer_phone'].toString(),
      vehicleName: j['vehicle_name'].toString(),
      vehiclePlate: j['vehicle_plate'].toString(),
      stops: stopsJson
          .map(
            (s) => StopCoordinate(
              seqOrder: ((s as Map<String, dynamic>)['seq_order'] as num?)?.toInt() ?? 1,
              stopType: (s['stop_type'] ?? 'pickup').toString(),
              address: (s['address'] ?? '').toString(),
              lat: (s['lat'] as num?)?.toDouble(),
              lng: (s['lng'] as num?)?.toDouble(),
            ),
          )
          .toList(),
      specialInstructions: j['special_instructions']?.toString(),
      trip: j['trip'] != null ? TripModel.fromJson(j['trip'] as Map<String, dynamic>) : null,
    );
  }

  final String assignmentId;
  final String assignmentStatus;
  final String bookingId;
  final String bookingReference;
  final String serviceName;
  final List<String> workflowSteps;
  final DateTime pickupAt;
  final DateTime expectedEndAt;
  final String customerName;
  final String customerPhone;
  final String vehicleName;
  final String vehiclePlate;
  final List<StopCoordinate> stops;
  final String? specialInstructions;
  final TripModel? trip;

  String? get nextMilestone {
    if (trip == null) return null;
    final idx = workflowSteps.indexOf(trip!.status);
    if (idx < 0 || idx + 1 >= workflowSteps.length) return null;
    final candidate = workflowSteps[idx + 1];
    if (candidate == 'service_completed') return null;
    return candidate;
  }

  @override
  List<Object?> get props => [assignmentId, assignmentStatus, bookingId, trip];
}

abstract class DriverOperationsRepository {
  Future<List<DriverAssignment>> listAssignments();
  Future<String> updateAvailability(String status);
  Future<TripModel> acknowledge(String assignmentId);
  Future<void> decline(String assignmentId, String reason);
  Future<TripModel> advanceMilestone({
    required String tripId,
    required String assignmentId,
    required String milestone,
    required double? lat,
    required double? lng,
    String? notes,
  });
  Future<TripModel> completeTrip({
    required String tripId,
    required int endOdometer,
    int waitingMinutes = 0,
    int extraChargesMinor = 0,
    String? notes,
  });
  Future<void> reportIncident({
    required String tripId,
    required String category,
    required String severity,
    required String description,
  });
  Future<int> flushOfflineActions();
}
