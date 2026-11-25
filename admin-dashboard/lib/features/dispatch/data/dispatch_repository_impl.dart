import '../../../core/error/failures.dart';
import '../../../core/network/dio_client.dart';
import '../domain/dispatch_entities.dart';

/// Dio-backed dispatch repository handling eligible lookup and atomic assign/reassign.
class DispatchRepositoryImpl implements DispatchRepository {
  DispatchRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<Result<EligibleResourcesBundle>> fetchEligibleResources(String bookingId) async {
    try {
      final res = await _api.raw.get<Map<String, dynamic>>(
        '/dispatch/eligible-resources',
        queryParameters: {'booking_id': bookingId},
      );
      final body = res.data!;
      final vehicles = (body['vehicles'] as List<dynamic>? ?? const []).map((raw) {
        final j = raw as Map<String, dynamic>;
        return EligibleVehicle(
          id: j['id'] as String,
          plateNumber: j['plate_number'] as String,
          name: j['name'] as String,
          seatCapacity: j['seat_capacity'] as int,
          isEligible: j['is_eligible'] as bool,
          conflictReason: j['conflict_reason'] as String?,
        );
      }).toList();
      final drivers = (body['drivers'] as List<dynamic>? ?? const []).map((raw) {
        final j = raw as Map<String, dynamic>;
        return EligibleDriver(
          id: j['id'] as String,
          fullName: j['full_name'] as String,
          licenceNumber: j['licence_number'] as String,
          isEligible: j['is_eligible'] as bool,
          conflictReason: j['conflict_reason'] as String?,
        );
      }).toList();
      return Success(EligibleResourcesBundle(vehicles: vehicles, drivers: drivers));
    } catch (e) {
      return Err(ApiClient.mapDioError(e));
    }
  }

  @override
  Future<Result<void>> assign({
    required String bookingId,
    required String vehicleId,
    required String driverId,
    required bool isReassignment,
    String? reason,
  }) async {
    try {
      final endpoint = isReassignment ? '/dispatch/reassign' : '/dispatch/assign';
      await _api.raw.post<Map<String, dynamic>>(
        endpoint,
        data: {
          'booking_id': bookingId,
          'vehicle_id': vehicleId,
          'driver_id': driverId,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
      );
      return const Success(null);
    } catch (e) {
      return Err(ApiClient.mapDioError(e));
    }
  }
}
