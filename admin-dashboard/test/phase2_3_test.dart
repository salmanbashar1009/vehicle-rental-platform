import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:velofleet_admin/core/network/dio_client.dart';
import 'package:velofleet_admin/core/theme/brand_theme.dart';
import 'package:velofleet_admin/features/live_map/presentation/live_map_bloc.dart';
import 'package:velofleet_admin/features/notifications/presentation/notifications_cubit.dart';
import 'package:velofleet_admin/features/notifications/presentation/notifications_page.dart';

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

class _AdminStubAdapter implements HttpClientAdapter {
  bool markedRead = false;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    dynamic payload;
    if (options.path == '/tracking/fleet/live') {
      payload = [
        {
          'vehicle_id': 'v1',
          'vehicle_plate': 'VIP-1',
          'vehicle_name': 'S-Class',
          'driver_id': 'd1',
          'driver_name': 'Karim',
          'booking_id': 'b1',
          'booking_reference': 'VF-101',
          'trip_id': 't1',
          'trip_status': 'journey_started',
          'lat': 23.81,
          'lng': 90.41,
          'freshness': 'live',
        },
      ];
    } else if (options.path == '/tracking/trips/t1/route') {
      payload = [
        {'lat': 23.80, 'lng': 90.40, 'recorded_at': '2026-12-20T10:00:00Z'},
        {'lat': 23.81, 'lng': 90.41, 'recorded_at': '2026-12-20T10:05:00Z'},
      ];
    } else if (options.path == '/notifications') {
      payload = [
        {
          'id': 'n1',
          'event_type': 'assignment.declined',
          'title': 'Driver declined VF-101',
          'body': 'Flat tire reported',
          'priority': 'high',
          'read_at': markedRead ? '2026-12-20T10:10:00Z' : null,
          'created_at': '2026-12-20T10:00:00Z',
        },
      ];
    } else if (options.path == '/incidents') {
      payload = [
        {
          'id': 'i1',
          'trip_id': 't1',
          'category': 'breakdown',
          'severity': 'critical',
          'description': 'Alternator warning light',
          'status': 'open',
          'created_at': '2026-12-20T10:01:00Z',
        },
      ];
    } else if (options.path == '/notifications/n1/read') {
      markedRead = true;
      payload = {'status': 'read'};
    } else {
      payload = {};
    }

    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }
}

void main() {
  test('LiveMapBloc loads active fleet, applies telemetry delta, and loads playback route', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.httpClientAdapter = _AdminStubAdapter();
    final api = ApiClient(vault: _MemVault(), dio: dio);
    final bloc = LiveMapBloc(api, connectWs: false);

    bloc.add(const LiveMapStarted());
    await bloc.stream.firstWhere((s) => s.vehicles.isNotEmpty);
    expect(bloc.state.vehicles.length, 1);
    expect(bloc.state.vehicles.first.freshness, 'live');

    bloc.add(LiveVehicleSelected(bloc.state.vehicles.first));
    await bloc.stream.firstWhere((s) => s.playbackPolyline.isNotEmpty);
    expect(bloc.state.playbackPolyline.length, 2);

    bloc.add(
      const LiveTelemetryReceived({
        'vehicle_id': 'v1',
        'lat': 23.825,
        'lng': 90.425,
        'freshness': 'stale',
      }),
    );
    await bloc.stream.firstWhere((s) => s.selected?.freshness == 'stale');
    expect(bloc.state.selected?.lat, 23.825);
    expect(bloc.state.selected?.freshness, 'stale');
    await bloc.close();
  });

  testWidgets('NotificationsPage displays notifications and driver incidents', (tester) async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.httpClientAdapter = _AdminStubAdapter();
    final cubit = NotificationsCubit(ApiClient(vault: _MemVault(), dio: dio));

    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(theme: buildAdminTheme(), home: const NotificationsPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Driver declined VF-101'), findsOneWidget);
    expect(find.text('Alternator warning light'), findsOneWidget);

    await tester.tap(find.text('Mark Read'));
    await tester.pumpAndSettle();
    expect(cubit.state.unreadCount, 0);
  });
}
