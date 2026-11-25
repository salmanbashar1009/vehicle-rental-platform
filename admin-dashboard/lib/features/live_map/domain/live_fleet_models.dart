import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

/// Active vehicle telemetry item rendered on Live Fleet Map.
class LiveFleetVehicle extends Equatable {
  const LiveFleetVehicle({
    required this.vehicleId,
    required this.vehiclePlate,
    required this.vehicleName,
    required this.driverId,
    required this.driverName,
    required this.bookingId,
    required this.bookingReference,
    required this.tripId,
    required this.tripStatus,
    required this.freshness,
    this.lat,
    this.lng,
    this.speedMps,
    this.recordedAt,
  });

  factory LiveFleetVehicle.fromJson(Map<String, dynamic> j) => LiveFleetVehicle(
    vehicleId: j['vehicle_id'].toString(),
    vehiclePlate: j['vehicle_plate'].toString(),
    vehicleName: j['vehicle_name'].toString(),
    driverId: j['driver_id'].toString(),
    driverName: j['driver_name'].toString(),
    bookingId: j['booking_id'].toString(),
    bookingReference: j['booking_reference'].toString(),
    tripId: j['trip_id'].toString(),
    tripStatus: j['trip_status'].toString(),
    freshness: (j['freshness'] ?? 'offline').toString(),
    lat: (j['lat'] as num?)?.toDouble(),
    lng: (j['lng'] as num?)?.toDouble(),
    speedMps: (j['speed_mps'] as num?)?.toDouble(),
    recordedAt: j['recorded_at'] != null ? DateTime.tryParse(j['recorded_at'].toString()) : null,
  );

  final String vehicleId;
  final String vehiclePlate;
  final String vehicleName;
  final String driverId;
  final String driverName;
  final String bookingId;
  final String bookingReference;
  final String tripId;
  final String tripStatus;
  final String freshness;
  final double? lat;
  final double? lng;
  final double? speedMps;
  final DateTime? recordedAt;

  LiveFleetVehicle applyLocationUpdate(Map<String, dynamic> payload) => LiveFleetVehicle(
    vehicleId: vehicleId,
    vehiclePlate: vehiclePlate,
    vehicleName: vehicleName,
    driverId: driverId,
    driverName: driverName,
    bookingId: bookingId,
    bookingReference: bookingReference,
    tripId: tripId,
    tripStatus: tripStatus,
    freshness: (payload['freshness'] ?? freshness).toString(),
    lat: (payload['lat'] as num?)?.toDouble() ?? lat,
    lng: (payload['lng'] as num?)?.toDouble() ?? lng,
    speedMps: (payload['speed_mps'] as num?)?.toDouble() ?? speedMps,
    recordedAt: payload['recorded_at'] != null
        ? DateTime.tryParse(payload['recorded_at'].toString())
        : recordedAt,
  );

  LatLng? get position => (lat != null && lng != null) ? LatLng(lat!, lng!) : null;

  @override
  List<Object?> get props => [vehicleId, tripStatus, freshness, lat, lng, recordedAt];
}
