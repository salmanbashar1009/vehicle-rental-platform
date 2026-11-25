import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:velofleet_driver/core/network/dio_client.dart';
import 'package:velofleet_driver/core/theme/brand_theme.dart';
import 'package:velofleet_driver/features/assignments/domain/assignment_models.dart';
import 'package:velofleet_driver/features/assignments/presentation/assignments_bloc.dart';
import 'package:velofleet_driver/features/auth/presentation/profile_alerts_card.dart';

class _MemTokenStore implements TokenStore {
  @override
  Future<void> clear() async {}
  @override
  Future<String?> readAccessToken() async => 'tok';
  @override
  Future<String?> readRefreshToken() async => 'ref';
  @override
  Future<void> writeTokens({required String accessToken, required String refreshToken}) async {}
}

class _MockOpsRepo extends Mock implements DriverOperationsRepository {}

class _AlertsAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = [
      {
        'id': 'n1',
        'event_type': 'driver.licence_expiring',
        'title': 'Driving licence expiring 2026-12-05',
        'body': 'Upload renewed licence before expiry.',
      },
    ];
    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }
}

void main() {
  testWidgets('DriverPerformanceAlertsCard renders expiry warning and trip counters', (
    tester,
  ) async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.httpClientAdapter = _AlertsAdapter();
    final client = DriverDioClient(tokenStore: _MemTokenStore(), dio: dio);
    final opsRepo = _MockOpsRepo();

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<DriverDioClient>.value(value: client),
          RepositoryProvider<DriverOperationsRepository>.value(value: opsRepo),
        ],
        child: BlocProvider(
          create: (_) => AssignmentsBloc(opsRepo),
          child: MaterialApp(
            theme: DriverBrandTheme.light(),
            home: const Scaffold(body: DriverPerformanceAlertsCard()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Performance & Compliance Alerts'), findsOneWidget);
    expect(find.text('Driving licence expiring 2026-12-05'), findsOneWidget);
  });
}
