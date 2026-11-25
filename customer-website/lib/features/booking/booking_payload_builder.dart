/// Validation & payload normalization helpers for booking request submissions.
String normalizeUtcIsoTimestamp(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(trimmed)) {
    return trimmed;
  }
  if (RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$').hasMatch(trimmed)) {
    return '$trimmed:00Z';
  }
  if (RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$').hasMatch(trimmed)) {
    return '${trimmed}Z';
  }
  return trimmed;
}

/// Validates booking inputs and returns a request body for POST /bookings, or throws [FormatException].
Map<String, dynamic> buildBookingRequestPayload({
  required String serviceSlug,
  String? preferredVehicleId,
  required String pickupAtRaw,
  required String expectedEndAtRaw,
  required String passengersRaw,
  required String luggageRaw,
  required String pickupAddress,
  required String destinationAddress,
  required List<String> waypoints,
  required Map<String, String> extraMeta,
  required String notes,
  required bool isAuthenticated,
  required String customerName,
  required String customerEmail,
  required String customerPhone,
}) {
  if (pickupAddress.trim().length < 2 || destinationAddress.trim().length < 2) {
    throw const FormatException('Pickup and destination addresses are required.');
  }
  final pickupIso = normalizeUtcIsoTimestamp(pickupAtRaw);
  final endIso = normalizeUtcIsoTimestamp(expectedEndAtRaw);
  final pickupDt = DateTime.tryParse(pickupIso);
  final endDt = DateTime.tryParse(endIso);
  if (pickupDt == null || endDt == null) {
    throw const FormatException('Please enter valid pickup and return date/times.');
  }
  if (!endDt.isAfter(pickupDt)) {
    throw const FormatException('Expected return time must be after pickup time.');
  }
  final passengerCount = int.tryParse(passengersRaw.trim()) ?? 0;
  final luggageCount = int.tryParse(luggageRaw.trim()) ?? -1;
  if (passengerCount < 1) {
    throw const FormatException('At least 1 passenger is required.');
  }
  if (luggageCount < 0) {
    throw const FormatException('Luggage count cannot be negative.');
  }
  if (!isAuthenticated &&
      (customerName.trim().length < 2 ||
          (customerEmail.trim().isEmpty && customerPhone.trim().length < 6))) {
    throw const FormatException('Please provide your full name and email or phone number.');
  }

  final cleanedMeta = <String, String>{
    for (final entry in extraMeta.entries)
      if (entry.value.trim().isNotEmpty) entry.key: entry.value.trim(),
  };

  final stops = <Map<String, String>>[
    {'stop_type': 'pickup', 'address': pickupAddress.trim()},
    for (final wp in waypoints)
      if (wp.trim().isNotEmpty) {'stop_type': 'waypoint', 'address': wp.trim()},
    {'stop_type': 'destination', 'address': destinationAddress.trim()},
  ];

  final vehicleId = preferredVehicleId?.trim();
  return <String, dynamic>{
    'service_slug': serviceSlug,
    if (vehicleId != null && vehicleId.isNotEmpty) 'preferred_vehicle_id': vehicleId,
    'pickup_at': pickupIso,
    'expected_end_at': endIso,
    'passenger_count': passengerCount,
    'luggage_count': luggageCount,
    'service_metadata_json': cleanedMeta,
    if (notes.trim().isNotEmpty) 'special_instructions': notes.trim(),
    'stops': stops,
    if (!isAuthenticated) ...{
      'customer_name': customerName.trim(),
      if (customerEmail.trim().isNotEmpty) 'customer_email': customerEmail.trim(),
      if (customerPhone.trim().isNotEmpty) 'customer_phone': customerPhone.trim(),
    },
  };
}
