import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:velofleet_admin/core/network/dio_client.dart';
import 'package:velofleet_admin/core/theme/brand_theme.dart';
import 'package:velofleet_admin/features/operations/presentation/maintenance_crm_page.dart';
import 'package:velofleet_admin/features/operations/presentation/ops_cubit.dart';
import 'package:velofleet_admin/features/operations/presentation/reports_reviews_page.dart';

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

class _OpsStubAdapter implements HttpClientAdapter {
  bool hidden = false;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    dynamic data;
    if (options.path == '/maintenance') {
      data = [
        {
          'id': 'm1',
          'maint_type': 'oil_change',
          'description': 'Quarterly synthetic oil service',
          'scheduled_start': '2026-12-28T09:00:00Z',
          'status': 'scheduled',
        },
      ];
    } else if (options.path == '/maintenance/expiry-scan') {
      data = {'doc_alerts_created': 2, 'licence_alerts_created': 1};
    } else if (options.path == '/corporate/accounts') {
      data = [
        {
          'id': 'c1',
          'company_name': 'Acme Corp',
          'billing_cycle': 'monthly',
          'negotiated_discount_bps': 500,
          'is_active': true,
        },
      ];
    } else if (options.path == '/crm/customers') {
      data = [
        {
          'id': 'cu1',
          'full_name': 'Alice Corporate',
          'email': 'alice@acme.com',
          'customer_type': 'corporate',
          'total_bookings': 4,
        },
      ];
    } else if (options.path == '/reports/operations') {
      data = {
        'vehicle_utilization_pct': 75.0,
        'cancellation_rate_pct': 5.0,
        'repeat_customers': 12,
      };
    } else if (options.path == '/reviews') {
      data = [
        {
          'id': 'r1',
          'overall_rating': 5,
          'driver_rating': 5,
          'comment': 'Punctual chauffeur',
          'moderation_status': hidden ? 'hidden' : 'published',
        },
      ];
    } else if (options.path == '/reviews/r1/moderate') {
      hidden = true;
      data = {'id': 'r1', 'moderation_status': 'hidden'};
    } else {
      data = {};
    }
    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }
}

void main() {
  testWidgets('MaintenanceCrmPage scans expiries and shows corporate CRM accounts', (tester) async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.httpClientAdapter = _OpsStubAdapter();
    final cubit = OpsCubit(ApiClient(vault: _MemVault(), dio: dio));

    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(theme: buildAdminTheme(), home: const MaintenanceCrmPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Quarterly synthetic oil service'), findsOneWidget);
    expect(find.text('Acme Corp'), findsOneWidget);

    await tester.tap(find.text('Scan Expiries'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Doc alerts: 2'), findsOneWidget);
  });

  testWidgets('ReportsAndReviewsPage displays KPIs and moderates reviews', (tester) async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.httpClientAdapter = _OpsStubAdapter();
    final cubit = OpsCubit(ApiClient(vault: _MemVault(), dio: dio));

    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(theme: buildAdminTheme(), home: const ReportsAndReviewsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('75.0%'), findsOneWidget);
    expect(find.text('Punctual chauffeur'), findsOneWidget);

    await tester.tap(find.text('Hide'));
    await tester.pumpAndSettle();
    expect(find.text('HIDDEN'), findsOneWidget);
  });
}
