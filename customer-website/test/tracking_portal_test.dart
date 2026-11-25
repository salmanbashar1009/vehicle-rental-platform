import 'package:jaspr_test/jaspr_test.dart';

import 'package:velofleet_customer_web/core/models/tracking_models.dart';
import 'package:velofleet_customer_web/features/portal/active_trip_tracking_page.dart';

void main() {
  group('Customer Tracking Models & Portal', () {
    test('BookingTrackingDto parses active and inactive tracking payloads', () {
      final active = BookingTrackingDto.fromJson({
        'booking_id': 'b-1',
        'booking_reference': 'VF-2026-100',
        'trip_status': 'en_route_to_pickup',
        'tracking_active': true,
        'vehicle_name': 'Executive Sedan',
        'vehicle_plate': 'VIP-10',
        'driver_display_name': 'Ali',
        'lat': 23.8103,
        'lng': 90.4125,
        'freshness': 'live',
        'stops': [
          {'seq_order': 1, 'stop_type': 'pickup', 'address': 'Airport Terminal 1'},
        ],
      });
      expect(active.trackingActive, isTrue);
      expect(active.driverDisplayName, 'Ali');
      expect(active.freshness, 'live');
      expect(active.stops.first.address, 'Airport Terminal 1');

      final inactive = BookingTrackingDto.fromJson({
        'booking_id': 'b-2',
        'booking_reference': 'VF-2026-101',
        'trip_status': 'service_completed',
        'tracking_active': false,
        'freshness': 'offline',
        'stops': const [],
      });
      expect(inactive.trackingActive, isFalse);
      expect(inactive.lat, isNull);
    });

    testComponents('ActiveTripTrackingPage renders unauthenticated tracking shell cleanly', (
      tester,
    ) async {
      tester.pumpComponent(const ActiveTripTrackingPage(bookingId: 'b-1'));
      expect(find.text('Active Trip Tracking'), findsOneComponent);
    });
  });
}
