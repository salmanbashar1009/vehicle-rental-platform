import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:velofleet_admin/core/error/failures.dart';
import 'package:velofleet_admin/core/widgets/status_badge.dart';
import 'package:velofleet_admin/features/auth/domain/auth_entities.dart';
import 'package:velofleet_admin/features/auth/presentation/auth_bloc.dart';
import 'package:velofleet_admin/features/bookings/domain/booking_entity.dart';
import 'package:velofleet_admin/features/bookings/presentation/booking_bloc.dart';
import 'package:velofleet_admin/features/dispatch/domain/dispatch_entities.dart';
import 'package:velofleet_admin/features/dispatch/presentation/dispatch_bloc.dart';

class _MockAuthRepo extends Mock implements AuthRepository {}

class _MockBookingRepo extends Mock implements AdminBookingRepository {}

class _MockDispatchRepo extends Mock implements DispatchRepository {}

void main() {
  group('Admin Dashboard Unit & BLoC Tests', () {
    test('formatMinorCurrency formats deterministic minor units without floats', () {
      expect(formatMinorCurrency(15000, 'USD'), 'USD 150.00');
      expect(formatMinorCurrency(5, 'USD'), 'USD 0.05');
      expect(formatMinorCurrency(-250, 'EUR'), '-EUR 2.50');
    });

    blocTest<AuthBloc, AuthState>(
      'AuthBloc emits Submitting -> Authenticated on valid staff login',
      build: () {
        final repo = _MockAuthRepo();
        when(
          () => repo.login(identifier: 'owner@vf.test', password: 'secret'),
        ).thenAnswer(
          (_) async => const Success(
            StaffUser(
              id: 'u1',
              fullName: 'Owner',
              roles: {'owner'},
              permissions: {'bookings.read'},
            ),
          ),
        );
        return AuthBloc(repo);
      },
      act: (b) => b.add(const AuthLoginSubmitted(identifier: 'owner@vf.test', password: 'secret')),
      expect: () => [
        const AuthSubmitting(),
        isA<AuthAuthenticated>().having((s) => s.user.fullName, 'fullName', 'Owner'),
      ],
    );

    blocTest<BookingBloc, BookingState>(
      'BookingBloc preserves items and emits actionFailure on 409 conflict',
      build: () {
        final repo = _MockBookingRepo();
        final sample = AdminBookingEntity(
          id: 'b1',
          reference: 'VF-20261201-0001',
          status: 'requested',
          pickupAt: DateTime.utc(2026, 12, 1, 9),
          expectedEndAt: DateTime.utc(2026, 12, 1, 13),
          passengerCount: 2,
          luggageCount: 1,
          pickupAddress: 'Airport',
          destinationAddress: 'Downtown',
        );
        when(() => repo.listBookings(status: null, search: '')).thenAnswer((_) async => Success([sample]));
        when(() => repo.confirmBooking(bookingId: 'b1')).thenAnswer(
          (_) async => const Err(ConflictFailure(message: 'Vehicle already reserved.')),
        );
        return BookingBloc(repo);
      },
      act: (b) async {
        b.add(const BookingsFetchRequested());
        await Future<void>.delayed(Duration.zero);
        b.add(const BookingConfirmRequested(bookingId: 'b1'));
      },
      verify: (b) {
        expect(b.state.items.length, 1);
        expect(b.state.actionFailure, isA<ConflictFailure>());
      },
    );

    blocTest<DispatchBloc, DispatchState>(
      'DispatchBloc refreshes eligible resources after 409 conflict',
      build: () {
        final repo = _MockDispatchRepo();
        when(
          () => repo.assign(
            bookingId: 'b1',
            vehicleId: 'v1',
            driverId: 'd1',
            isReassignment: false,
          ),
        ).thenAnswer((_) async => const Err(ConflictFailure(message: 'Overlap detected.')));
        when(() => repo.fetchEligibleResources('b1')).thenAnswer(
          (_) async => const Success(
            EligibleResourcesBundle(
              vehicles: [
                EligibleVehicle(
                  id: 'v1',
                  plateNumber: 'VF-100',
                  name: 'Sedan',
                  seatCapacity: 4,
                  isEligible: false,
                  conflictReason: 'schedule_overlap',
                ),
              ],
              drivers: [],
            ),
          ),
        );
        return DispatchBloc(repo);
      },
      act: (b) => b.add(const DispatchAssignSubmitted(bookingId: 'b1', vehicleId: 'v1', driverId: 'd1')),
      verify: (b) {
        expect(b.state.failure, isA<ConflictFailure>());
        expect(b.state.vehicles.first.isEligible, isFalse);
      },
    );
  });
}
