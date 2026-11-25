/// Typed tracking DTO matching GET /api/v1/bookings/{id}/tracking.
class TrackingStopDto {
  const TrackingStopDto({required this.seqOrder, required this.stopType, required this.address});

  factory TrackingStopDto.fromJson(Map<String, dynamic> j) => TrackingStopDto(
    seqOrder: (j['seq_order'] as num?)?.toInt() ?? 1,
    stopType: (j['stop_type'] ?? 'pickup').toString(),
    address: (j['address'] ?? '').toString(),
  );

  final int seqOrder;
  final String stopType;
  final String address;
}

class BookingTrackingDto {
  const BookingTrackingDto({
    required this.bookingId,
    required this.bookingReference,
    required this.tripStatus,
    required this.trackingActive,
    required this.freshness,
    required this.stops,
    this.vehicleName,
    this.vehiclePlate,
    this.driverDisplayName,
    this.lat,
    this.lng,
    this.recordedAt,
  });

  factory BookingTrackingDto.fromJson(Map<String, dynamic> j) {
    final stopsJson = (j['stops'] as List<dynamic>?) ?? const [];
    return BookingTrackingDto(
      bookingId: j['booking_id'].toString(),
      bookingReference: j['booking_reference'].toString(),
      tripStatus: j['trip_status'].toString(),
      trackingActive: j['tracking_active'] == true,
      freshness: (j['freshness'] ?? 'offline').toString(),
      vehicleName: j['vehicle_name']?.toString(),
      vehiclePlate: j['vehicle_plate']?.toString(),
      driverDisplayName: j['driver_display_name']?.toString(),
      lat: (j['lat'] as num?)?.toDouble(),
      lng: (j['lng'] as num?)?.toDouble(),
      recordedAt: j['recorded_at']?.toString(),
      stops: stopsJson.map((s) => TrackingStopDto.fromJson(s as Map<String, dynamic>)).toList(),
    );
  }

  final String bookingId;
  final String bookingReference;
  final String tripStatus;
  final bool trackingActive;
  final String freshness;
  final String? vehicleName;
  final String? vehiclePlate;
  final String? driverDisplayName;
  final double? lat;
  final double? lng;
  final String? recordedAt;
  final List<TrackingStopDto> stops;
}
