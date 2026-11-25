import 'package:jaspr_test/jaspr_test.dart';
import 'package:velofleet_customer_web/components/ui/catalog_cards.dart';
import 'package:velofleet_customer_web/components/ui/ui_primitives.dart';
import 'package:velofleet_customer_web/core/http/api_client.dart';
import 'package:velofleet_customer_web/core/http/api_error.dart';
import 'package:velofleet_customer_web/core/models/booking_models.dart';
import 'package:velofleet_customer_web/core/models/catalog_models.dart';

void main() {
  group('Customer Website DTOs, Errors & Components', () {
    test('generateUuidV4 emits valid UUID v4 strings for Idempotency-Key', () {
      final a = generateUuidV4();
      final b = generateUuidV4();
      expect(a, isNot(equals(b)));
      expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(a), isTrue);
    });

    test('ApiError maps backend ErrorEnvelope payload cleanly', () {
      final err = ApiError.fromJson({
        'error': {
          'code': 'RESOURCE_CONFLICT',
          'message': 'Selected vehicle is unavailable.',
          'correlation_id': 'corr-123',
        },
      }, 409);
      expect(err.statusCode, 409);
      expect(err.code, 'RESOURCE_CONFLICT');
      expect(err.correlationId, 'corr-123');
    });

    test('VehicleDto and BookingDto deserialize FastAPI payloads', () {
      final vehicle = VehicleDto.fromJson({
        'id': 'v1',
        'plate_number': 'VF-100',
        'name': 'Executive Van',
        'category': 'van',
        'make': 'Toyota',
        'model': 'Hiace',
        'year': 2025,
        'seat_capacity': 10,
        'luggage_capacity': 8,
        'fuel_type': 'diesel',
        'facilities_json': ['ac', 'wifi'],
        'indicative_daily_rate_minor': 18000,
        'currency': 'USD',
        'status': 'available',
        'images': [],
      });
      expect(vehicle.formattedDailyRate, 'USD 180 / day');

      final booking = BookingDto.fromJson({
        'id': 'b1',
        'reference': 'VF-20261201-ABC123',
        'status': 'requested',
        'pickup_at': '2026-12-01T09:00:00Z',
        'expected_end_at': '2026-12-01T13:00:00Z',
        'passenger_count': 4,
        'luggage_count': 2,
        'stops': [
          {'stop_type': 'pickup', 'address': 'Airport Terminal 1'},
          {'stop_type': 'destination', 'address': 'City Hotel'},
        ],
        'status_history': [
          {'from_status': null, 'to_status': 'requested', 'reason': 'Submitted', 'created_at': '2026-11-25T10:00:00Z'},
        ],
      });
      expect(booking.stops.length, 2);
      expect(booking.timeline.first.toStatus, 'requested');
    });

    testComponents('StatusBadge and VehicleCard render expected states', (tester) async {
      tester.pumpComponent(const StatusBadge(status: 'confirmed'));
      expect(find.text('CONFIRMED'), findsOneComponent);

      tester.pumpComponent(
        const VehicleCard(
          vehicle: VehicleDto(
            id: 'v1',
            plateNumber: 'VF-100',
            name: 'Luxury Sedan',
            category: 'sedan',
            make: 'Mercedes',
            model: 'E-Class',
            year: 2025,
            seatCapacity: 3,
            luggageCapacity: 3,
            fuelType: 'hybrid',
            facilities: ['ac', 'leather'],
            indicativeDailyRateMinor: 25000,
            currency: 'USD',
            status: 'available',
          ),
        ),
      );
      expect(find.text('Luxury Sedan'), findsOneComponent);
      expect(find.text('USD 250 / day'), findsOneComponent);
    });
  });
}
