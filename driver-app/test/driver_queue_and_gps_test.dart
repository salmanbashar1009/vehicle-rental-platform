import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:velofleet_driver/core/config/app_config.dart';
import 'package:velofleet_driver/core/network/dio_client.dart';
import 'package:velofleet_driver/core/storage/local_queue_db.dart';
import 'package:velofleet_driver/features/gps_tracking/presentation/gps_tracking_bloc.dart';

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

class _FakeAdapter implements HttpClientAdapter {
  final List<String> postedPaths = [];
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    postedPaths.add(options.path);
    return ResponseBody.fromString(
      '{"accepted_count":1,"persisted_count":1,"freshness":"live"}',
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }
}

class _MockDio extends Mock implements DriverDioClient {}

void main() {
  sqfliteFfiInit();

  test('LocalQueueDb stores pending actions FIFO and caps/batches GPS points', () async {
    final db = await LocalQueueDb.open(dbPath: inMemoryDatabasePath, factory: databaseFactoryFfi);
    await db.enqueueTripAction(
      const QueuedTripAction(
        idempotencyKey: 'k2',
        assignmentId: 'a1',
        actionType: 'milestone',
        payload: {'milestone': 'arrived_at_pickup'},
        occurredAtUtc: '2026-12-20T10:05:00Z',
        createdAtMs: 200,
      ),
    );
    await db.enqueueTripAction(
      const QueuedTripAction(
        idempotencyKey: 'k1',
        assignmentId: 'a1',
        actionType: 'milestone',
        payload: {'milestone': 'en_route_to_pickup'},
        occurredAtUtc: '2026-12-20T10:00:00Z',
        createdAtMs: 100,
      ),
    );
    final ordered = await db.pendingTripActions();
    expect(ordered.map((e) => e.idempotencyKey).toList(), ['k1', 'k2']);

    for (var i = 0; i < 25; i++) {
      await db.enqueueGpsPoint(
        QueuedGpsPoint(
          assignmentId: 'a1',
          lat: 23.81 + i * 0.001,
          lng: 90.41,
          recordedAtUtc: '2026-12-20T10:00:${i.toString().padLeft(2, '0')}Z',
        ),
      );
    }
    expect(await db.bufferedGpsCount(), 25);
    final batch = await db.peekGpsBatch();
    expect(batch.length, AppConfig.gpsMaxBatchSize);
    await db.deleteGpsPoints(batch.map((e) => e.id!).toList());
    expect(await db.bufferedGpsCount(), 5);
    await db.close();
  });

  test('GpsTrackingBloc strictly discards outside active window and flushes inside window', () async {
    final db = await LocalQueueDb.open(dbPath: inMemoryDatabasePath, factory: databaseFactoryFfi);
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    final adapter = _FakeAdapter();
    dio.httpClientAdapter = adapter;
    final client = DriverDioClient(tokenStore: _MemTokenStore(), dio: dio);
    final bloc = GpsTrackingBloc(client, db);

    // Outside active trip window -> sample ignored
    bloc.add(const GpsSampleCaptured(lat: 23.81, lng: 90.41, speedMps: 5.0));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await db.bufferedGpsCount(), 0);
    expect(bloc.state.isActive, isFalse);

    // Enter active window -> sample buffered & flushed
    bloc.add(const GpsTripWindowEvaluated(assignmentId: 'assign-1', tripStatus: 'en_route_to_pickup'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(bloc.state.isActive, isTrue);

    bloc.add(const GpsSampleCaptured(lat: 23.81, lng: 90.41, speedMps: 6.0));
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(adapter.postedPaths, contains('/tracking/locations/batch'));
    expect(bloc.state.intervalSec, AppConfig.movingIntervalSec);

    // Close window -> tracking turns off immediately
    bloc.add(const GpsTripWindowEvaluated(assignmentId: 'assign-1', tripStatus: 'service_completed'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(bloc.state.isActive, isFalse);

    await bloc.close();
    await db.close();
  });

  test('Unused mock sanity check', () {
    expect(_MockDio(), isA<DriverDioClient>());
  });
}
