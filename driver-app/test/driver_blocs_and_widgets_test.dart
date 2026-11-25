import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:velofleet_driver/core/error/failures.dart';
import 'package:velofleet_driver/core/theme/brand_theme.dart';
import 'package:velofleet_driver/core/widgets/driver_widgets.dart';
import 'package:velofleet_driver/features/assignments/domain/assignment_models.dart';
import 'package:velofleet_driver/features/assignments/presentation/assignments_bloc.dart';
import 'package:velofleet_driver/features/auth/domain/auth_models.dart';
import 'package:velofleet_driver/features/auth/presentation/auth_bloc.dart';
import 'package:velofleet_driver/features/auth/presentation/login_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class _MockAuthRepo extends Mock implements DriverAuthRepository {}

class _MockOpsRepo extends Mock implements DriverOperationsRepository {}

void main() {
  late _MockAuthRepo authRepo;
  late _MockOpsRepo opsRepo;

  setUp(() {
    authRepo = _MockAuthRepo();
    opsRepo = _MockOpsRepo();
  });

  group('DriverAuthBloc', () {
    blocTest<DriverAuthBloc, DriverAuthState>(
      'emits DriverAuthenticated when login succeeds',
      build: () {
        when(() => authRepo.login(identifier: '+1555', password: 'secret')).thenAnswer(
          (_) async => const DriverSession(
            userId: 'u1',
            fullName: 'Karim',
            email: 'karim@vf.test',
            roles: ['driver'],
          ),
        );
        return DriverAuthBloc(authRepo);
      },
      act: (b) => b.add(const DriverLoginSubmitted(identifier: '+1555', password: 'secret')),
      expect: () => [
        const DriverAuthLoading(),
        isA<DriverAuthenticated>(),
      ],
    );

    blocTest<DriverAuthBloc, DriverAuthState>(
      'emits DriverUnauthenticated with message on AuthFailure',
      build: () {
        when(() => authRepo.login(identifier: 'bad', password: 'pw'))
            .thenThrow(const AuthFailure('Invalid driver credentials'));
        return DriverAuthBloc(authRepo);
      },
      act: (b) => b.add(const DriverLoginSubmitted(identifier: 'bad', password: 'pw')),
      expect: () => [
        const DriverAuthLoading(),
        const DriverUnauthenticated('Invalid driver credentials'),
      ],
    );
  });

  group('Assignment workflow & widgets', () {
    test('nextMilestone respects cargo workflow and stops before completion', () {
      final a = DriverAssignment(
        assignmentId: 'a1',
        assignmentStatus: 'active',
        bookingId: 'b1',
        bookingReference: 'VF-CARGO-1',
        serviceName: 'Cargo',
        workflowSteps: const ['assigned', 'en_route_to_pickup', 'loading_started', 'service_completed'],
        pickupAt: DateTime.utc(2026, 12, 20),
        expectedEndAt: DateTime.utc(2026, 12, 20, 4),
        customerName: 'Nadia',
        customerPhone: '+1555000',
        vehicleName: 'Box Truck',
        vehiclePlate: 'CRG-9',
        stops: const [],
        trip: const TripModel(id: 't1', assignmentId: 'a1', status: 'loading_started'),
      );
      expect(a.nextMilestone, isNull); // service_completed triggers completion dialog
      expect(a.trip!.isTrackingWindowOpen, isTrue);
    });

    blocTest<AssignmentsBloc, AssignmentsState>(
      'flushes offline queue before loading assignments',
      build: () {
        when(() => opsRepo.flushOfflineActions()).thenAnswer((_) async => 1);
        when(() => opsRepo.listAssignments()).thenAnswer((_) async => const []);
        return AssignmentsBloc(opsRepo);
      },
      act: (b) => b.add(const AssignmentsRefreshed()),
      verify: (_) => verify(() => opsRepo.flushOfflineActions()).called(1),
    );

    testWidgets('DriverLoginPage and TrackingPill render in Light/Dark theme', (tester) async {
      await tester.pumpWidget(
        BlocProvider(
          create: (_) => DriverAuthBloc(authRepo),
          child: MaterialApp(
            theme: DriverBrandTheme.light(),
            darkTheme: DriverBrandTheme.dark(),
            home: const Scaffold(
              body: Column(
                children: [
                  TrackingPill(isActive: true, bufferedCount: 0),
                  Expanded(child: DriverLoginPage()),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('GPS Live'), findsOneWidget);
      expect(find.text('VeloFleet Chauffeur'), findsOneWidget);
    });
  });
}
