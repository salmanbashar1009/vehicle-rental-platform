import '../../../core/error/failures.dart';
import '../../../core/network/dio_client.dart';
import '../domain/booking_entity.dart';

/// Dio-backed repository for admin booking management.
class AdminBookingRepositoryImpl implements AdminBookingRepository {
  AdminBookingRepositoryImpl(this._api);
  final ApiClient _api;

  AdminBookingEntity _map(Map<String, dynamic> j) {
    final stops = (j['stops'] as List<dynamic>? ?? const [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
    final pickup = stops.isNotEmpty ? (stops.first['address'] as String) : '—';
    final dest = stops.length > 1 ? (stops.last['address'] as String) : '—';
    return AdminBookingEntity(
      id: j['id'] as String,
      reference: j['reference'] as String,
      status: j['status'] as String,
      pickupAt: DateTime.parse(j['pickup_at'] as String),
      expectedEndAt: DateTime.parse(j['expected_end_at'] as String),
      passengerCount: j['passenger_count'] as int,
      luggageCount: j['luggage_count'] as int,
      pickupAddress: pickup,
      destinationAddress: dest,
      preferredVehicleId: j['preferred_vehicle_id'] as String?,
      specialInstructions: j['special_instructions'] as String?,
      internalNotes: j['internal_notes'] as String?,
    );
  }

  @override
  Future<Result<List<AdminBookingEntity>>> listBookings({
    int page = 1,
    String? status,
    String? search,
  }) async {
    try {
      final res = await _api.raw.get<Map<String, dynamic>>(
        '/bookings',
        queryParameters: {
          'page': page,
          'page_size': 25,
          if (status != null && status.isNotEmpty) 'status_filter': status,
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        },
      );
      final items = (res.data!['items'] as List<dynamic>? ?? const [])
          .map((e) => _map(e as Map<String, dynamic>))
          .toList();
      return Success(items);
    } catch (e) {
      return Err(ApiClient.mapDioError(e));
    }
  }

  @override
  Future<Result<AdminBookingEntity>> confirmBooking({
    required String bookingId,
    String? reason,
  }) async {
    try {
      final res = await _api.raw.post<Map<String, dynamic>>(
        '/bookings/$bookingId/confirm',
        data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
      );
      return Success(_map(res.data!));
    } catch (e) {
      return Err(ApiClient.mapDioError(e));
    }
  }

  @override
  Future<Result<AdminBookingEntity>> cancelBooking({
    required String bookingId,
    required String reason,
  }) async {
    try {
      final res = await _api.raw.post<Map<String, dynamic>>(
        '/bookings/$bookingId/cancel',
        data: {'reason': reason},
      );
      return Success(_map(res.data!));
    } catch (e) {
      return Err(ApiClient.mapDioError(e));
    }
  }

  @override
  Future<Result<void>> sendQuotation({
    required String bookingId,
    required String label,
    required int amountMinor,
    required int depositMinor,
    required String currency,
    required DateTime validUntil,
  }) async {
    try {
      await _api.raw.post<Map<String, dynamic>>(
        '/bookings/$bookingId/quotations',
        data: {
          'items': [
            {'label': label, 'quantity': 1, 'unit_amount_minor': amountMinor},
          ],
          'deposit_minor': depositMinor,
          'currency': currency,
          'valid_until': validUntil.toUtc().toIso8601String(),
        },
      );
      return const Success(null);
    } catch (e) {
      return Err(ApiClient.mapDioError(e));
    }
  }
}
