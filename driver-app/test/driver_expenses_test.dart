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
import 'package:velofleet_driver/features/expenses/presentation/driver_expenses_page.dart';

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

class _ExpenseAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = options.path == '/finance/expenses'
        ? [
            {
              'id': 'e1',
              'category': 'driver_allowance',
              'amount_minor': 2500,
              'currency': 'USD',
              'description': 'Overnight highway allowance',
              'status': 'approved',
              'review_notes': 'Approved per policy',
            },
            {
              'id': 'e2',
              'category': 'toll',
              'amount_minor': 600,
              'currency': 'USD',
              'description': 'Bridge toll',
              'status': 'pending',
            },
          ]
        : {};
    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }
}

void main() {
  testWidgets('DriverExpensesPage totals approved allowance and lists expense status history', (
    tester,
  ) async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.httpClientAdapter = _ExpenseAdapter();
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
            home: const Scaffold(body: DriverExpensesPage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Approved Driver Allowance'), findsOneWidget);
    expect(find.text('USD 25.00'), findsOneWidget);
    expect(find.text('APPROVED'), findsOneWidget);
    expect(find.text('PENDING'), findsOneWidget);
  });
}
