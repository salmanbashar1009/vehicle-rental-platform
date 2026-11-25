import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:velofleet_admin/core/network/dio_client.dart';
import 'package:velofleet_admin/core/theme/brand_theme.dart';
import 'package:velofleet_admin/features/finance/presentation/finance_cubit.dart';
import 'package:velofleet_admin/features/finance/presentation/finance_page.dart';

class _MemVault implements TokenVault {
  @override
  Future<void> clear() async {}
  @override
  Future<String?> readAccessToken() async => 'tok';
  @override
  Future<String?> readRefreshToken() async => 'ref';
  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {}
}

class _FinanceStubAdapter implements HttpClientAdapter {
  bool approved = false;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    dynamic body;
    if (options.path == '/finance/summary') {
      body = {
        'currency': 'USD',
        'recognized_revenue_minor': 30000,
        'cash_collected_minor': 15000,
        'pending_collections_minor': 0,
        'refunded_minor': 0,
        'approved_expenses_minor': approved ? 1200 : 0,
        'net_cash_flow_minor': approved ? 13800 : 15000,
      };
    } else if (options.path == '/finance/expenses') {
      body = [
        {
          'id': 'exp-1',
          'booking_id': 'b-1',
          'category': 'toll',
          'amount_minor': 1200,
          'currency': 'USD',
          'description': 'Airport express toll',
          'status': approved ? 'approved' : 'pending',
        },
      ];
    } else if (options.path == '/finance/expenses/exp-1/decision') {
      approved = true;
      body = {'id': 'exp-1', 'status': 'approved'};
    } else {
      body = {};
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }
}

void main() {
  testWidgets('FinancePage loads cash-flow KPIs and approves pending expense', (tester) async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.httpClientAdapter = _FinanceStubAdapter();
    final cubit = FinanceCubit(ApiClient(vault: _MemVault(), dio: dio));

    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(theme: buildAdminTheme(), home: const FinancePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recognized Revenue'), findsOneWidget);
    expect(find.text('USD 150.00'), findsNWidgets(2));
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('Airport express toll'), findsOneWidget);

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(find.text('APPROVED'), findsOneWidget);
    expect(cubit.state.summary?.approvedExpensesMinor, 1200);
  });
}
