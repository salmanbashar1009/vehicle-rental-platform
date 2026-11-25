import '../../../core/error/failures.dart';
import '../../../core/network/dio_client.dart';
import '../domain/vehicle_entity.dart';

/// Dio-backed repository for fleet vehicle CRUD.
class FleetRepositoryImpl implements FleetRepository {
  FleetRepositoryImpl(this._api);
  final ApiClient _api;

  VehicleEntity _map(Map<String, dynamic> j) => VehicleEntity(
    id: j['id'] as String,
    plateNumber: j['plate_number'] as String,
    name: j['name'] as String,
    category: j['category'] as String,
    make: j['make'] as String,
    model: j['model'] as String,
    year: j['year'] as int,
    seatCapacity: j['seat_capacity'] as int,
    luggageCapacity: j['luggage_capacity'] as int,
    fuelType: j['fuel_type'] as String,
    status: j['status'] as String,
    odometerKm: j['odometer_km'] as int,
  );

  @override
  Future<Result<List<VehicleEntity>>> listVehicles({String? category}) async {
    try {
      final res = await _api.raw.get<Map<String, dynamic>>(
        '/vehicles',
        queryParameters: {'page': 1, 'page_size': 50, if (category != null) 'category': category},
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
  Future<Result<VehicleEntity>> createVehicle({
    required String plateNumber,
    required String name,
    required String category,
    required String make,
    required String model,
    required int year,
    required int seatCapacity,
    required String fuelType,
  }) async {
    try {
      final res = await _api.raw.post<Map<String, dynamic>>(
        '/vehicles',
        data: {
          'plate_number': plateNumber,
          'name': name,
          'category': category,
          'make': make,
          'model': model,
          'year': year,
          'seat_capacity': seatCapacity,
          'fuel_type': fuelType,
        },
      );
      return Success(_map(res.data!));
    } catch (e) {
      return Err(ApiClient.mapDioError(e));
    }
  }

  @override
  Future<Result<VehicleEntity>> updateStatus({
    required String vehicleId,
    required String status,
  }) async {
    try {
      final res = await _api.raw.patch<Map<String, dynamic>>(
        '/vehicles/$vehicleId',
        data: {'status': status},
      );
      return Success(_map(res.data!));
    } catch (e) {
      return Err(ApiClient.mapDioError(e));
    }
  }
}
