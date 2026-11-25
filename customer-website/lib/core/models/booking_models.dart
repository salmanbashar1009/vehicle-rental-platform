/// Booking stop DTO matching FastAPI schema.
class BookingStopDto {
  const BookingStopDto({required this.stopType, required this.address});

  final String stopType;
  final String address;

  factory BookingStopDto.fromJson(Map<String, dynamic> json) => BookingStopDto(
    stopType: json['stop_type'] as String,
    address: json['address'] as String,
  );

  Map<String, dynamic> toJson() => {'stop_type': stopType, 'address': address};
}

/// Booking status timeline entry DTO.
class BookingTimelineDto {
  const BookingTimelineDto({
    required this.toStatus,
    required this.createdAt,
    this.fromStatus,
    this.reason,
  });

  final String? fromStatus;
  final String toStatus;
  final String? reason;
  final DateTime createdAt;

  factory BookingTimelineDto.fromJson(Map<String, dynamic> json) => BookingTimelineDto(
    fromStatus: json['from_status'] as String?,
    toStatus: json['to_status'] as String,
    reason: json['reason'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

/// Booking record DTO matching FastAPI BookingResponse.
class BookingDto {
  const BookingDto({
    required this.id,
    required this.reference,
    required this.status,
    required this.pickupAt,
    required this.expectedEndAt,
    required this.passengerCount,
    required this.luggageCount,
    required this.stops,
    required this.timeline,
    this.specialInstructions,
    this.guestClaimToken,
  });

  final String id;
  final String reference;
  final String status;
  final DateTime pickupAt;
  final DateTime expectedEndAt;
  final int passengerCount;
  final int luggageCount;
  final List<BookingStopDto> stops;
  final List<BookingTimelineDto> timeline;
  final String? specialInstructions;
  final String? guestClaimToken;

  factory BookingDto.fromJson(Map<String, dynamic> json) => BookingDto(
    id: json['id'] as String,
    reference: json['reference'] as String,
    status: json['status'] as String,
    pickupAt: DateTime.parse(json['pickup_at'] as String),
    expectedEndAt: DateTime.parse(json['expected_end_at'] as String),
    passengerCount: json['passenger_count'] as int,
    luggageCount: json['luggage_count'] as int,
    stops: ((json['stops'] as List<dynamic>?) ?? const [])
        .map((e) => BookingStopDto.fromJson(e as Map<String, dynamic>))
        .toList(),
    timeline: ((json['status_history'] as List<dynamic>?) ?? const [])
        .map((e) => BookingTimelineDto.fromJson(e as Map<String, dynamic>))
        .toList(),
    specialInstructions: json['special_instructions'] as String?,
    guestClaimToken: json['guest_claim_token'] as String?,
  );
}
