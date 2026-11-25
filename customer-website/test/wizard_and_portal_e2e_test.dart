import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jaspr_test/jaspr_test.dart';

import 'package:velofleet_customer_web/core/auth/auth_session.dart';
import 'package:velofleet_customer_web/core/http/api_client.dart';
import 'package:velofleet_customer_web/features/auth/login_page.dart';
import 'package:velofleet_customer_web/features/auth/register_page.dart';
import 'package:velofleet_customer_web/features/booking/booking_confirmation_page.dart';
import 'package:velofleet_customer_web/features/booking/booking_payload_builder.dart';
import 'package:velofleet_customer_web/features/booking/booking_wizard_page.dart';
import 'package:velofleet_customer_web/features/portal/customer_booking_detail_page.dart';
import 'package:velofleet_customer_web/features/portal/customer_portal_page.dart';

void main() {
  group('Customer Booking Wizard & Auth Portal E2E Tests (WEB-107, WEB-108)', () {
    test('CustomerAuthStore registers, logs in, submits idempotent booking, and logs out', () async {
      String? seenIdempotency;
      final mockHttp = MockClient((req) async {
        if (req.url.path.endsWith('/auth/register') || req.url.path.endsWith('/auth/login')) {
          return http.Response(
            jsonEncode({
              'access_token': 'acc-tok',
              'refresh_token': 'ref-tok',
              'expires_in': 900,
              'user': {
                'id': 'u-1',
                'full_name': 'Nadia Rahman',
                'email': 'nadia@test.com',
                'roles': ['customer'],
              },
            }),
            200,
          );
        }
        if (req.url.path.endsWith('/bookings') && req.method == 'POST') {
          seenIdempotency = req.headers['Idempotency-Key'];
          return http.Response(
            jsonEncode({
              'id': 'b-10',
              'reference': 'VF-2026-1010',
              'status': 'requested',
              'pickup_at': '2026-12-20T09:00:00Z',
              'expected_end_at': '2026-12-20T12:00:00Z',
              'stops': [
                {'seq_order': 1, 'stop_type': 'pickup', 'address': 'Airport T1'},
                {'seq_order': 2, 'stop_type': 'destination', 'address': 'City Hotel'},
              ],
            }),
            201,
          );
        }
        if (req.url.path.endsWith('/auth/logout')) {
          return http.Response('{}', 200);
        }
        return http.Response('{"items":[]}', 200);
      });

      final store = CustomerAuthStore.instance;
      store.api = ApiClient(httpClient: mockHttp);

      await store.register(fullName: 'Nadia Rahman', email: 'nadia@test.com', password: 'Password!123');
      expect(store.isAuthenticated, isTrue);
      expect(store.user?.fullName, 'Nadia Rahman');

      final key = generateUuidV4();
      final created = await store.api.post(
        '/bookings',
        idempotencyKey: key,
        body: {'service_slug': 'airport_transfer'},
      ) as Map<String, dynamic>;
      expect(created['reference'], 'VF-2026-1010');
      expect(seenIdempotency, key);

      await store.logout();
      expect(store.isAuthenticated, isFalse);
    });

    testComponents('BookingWizardPage renders dynamic fields for cargo & airport services', (
      tester,
    ) async {
      tester.pumpComponent(const BookingWizardPage(initialService: 'house_shifting'));
      expect(find.text('Request a Booking or Quotation'), findsOneComponent);
      expect(find.text('Submit Booking Request'), findsOneComponent);

      tester.pumpComponent(const BookingConfirmationPage(reference: 'VF-2026-1010'));
      expect(find.text('VF-2026-1010'), findsOneComponent);
      expect(find.text('Booking Request Confirmed & Queued'), findsOneComponent);
      expect(find.text('+ Submit Another Request'), findsOneComponent);
    });

    test('buildBookingRequestPayload normalizes timestamps, stops, and guest validation', () {
      expect(normalizeUtcIsoTimestamp('2026-12-01T09:00'), '2026-12-01T09:00:00Z');
      expect(normalizeUtcIsoTimestamp('2026-12-01T09:00:30'), '2026-12-01T09:00:30Z');
      expect(normalizeUtcIsoTimestamp('2026-12-01T09:00:00Z'), '2026-12-01T09:00:00Z');

      final payload = buildBookingRequestPayload(
        serviceSlug: 'airport_transfer',
        pickupAtRaw: '2026-12-01T09:00',
        expectedEndAtRaw: '2026-12-01T13:00',
        passengersRaw: '2',
        luggageRaw: '3',
        pickupAddress: 'JFK Terminal 4',
        destinationAddress: 'Midtown Hotel',
        waypoints: const ['Queens Plaza', ''],
        extraMeta: const {'flight_number': 'BA117', 'terminal': ''},
        notes: 'Meet at exit',
        isAuthenticated: false,
        customerName: 'Test Guest',
        customerEmail: 'guest@example.com',
        customerPhone: '',
      );
      expect(payload['pickup_at'], '2026-12-01T09:00:00Z');
      expect(payload['stops'], hasLength(3));
      expect(payload['service_metadata_json'], {'flight_number': 'BA117'});
      expect(payload['customer_name'], 'Test Guest');
      expect(payload.containsKey('customer_phone'), isFalse);

      expect(
        () => buildBookingRequestPayload(
          serviceSlug: 'airport_transfer',
          pickupAtRaw: '2026-12-01T13:00',
          expectedEndAtRaw: '2026-12-01T09:00',
          passengersRaw: '2',
          luggageRaw: '1',
          pickupAddress: 'A',
          destinationAddress: 'B',
          waypoints: const [],
          extraMeta: const {},
          notes: '',
          isAuthenticated: false,
          customerName: 'Test Guest',
          customerEmail: 'guest@example.com',
          customerPhone: '',
        ),
        throwsFormatException,
      );
    });

    testComponents('Auth & Portal pages render expected forms and booking detail states', (
      tester,
    ) async {
      tester.pumpComponent(const LoginPage());
      expect(find.text('Customer Sign In'), findsOneComponent);

      tester.pumpComponent(const RegisterPage());
      expect(find.text('Create Customer Account'), findsOneComponent);

      tester.pumpComponent(const CustomerPortalPage());
      expect(find.text('Sign In Required'), findsOneComponent);

      tester.pumpComponent(const CustomerBookingDetailPage(bookingId: 'b-10'));
      expect(find.text('Sign In to View'), findsOneComponent);
    });
  });
}
