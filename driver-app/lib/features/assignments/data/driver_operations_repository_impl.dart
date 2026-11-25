import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import 'package:velofleet_driver/core/error/failures.dart';
import 'package:velofleet_driver/core/network/dio_client.dart';
import 'package:velofleet_driver/core/storage/local_queue_db.dart';
import 'package:velofleet_driver/features/assignments/domain/assignment_models.dart';

/// Concrete REST + offline FIFO repository for driver jobs and trip milestones.
class DriverOperationsRepositoryImpl implements DriverOperationsRepository {
  DriverOperationsRepositoryImpl(this._client, this._queue);

  final DriverDioClient _client;
  final LocalQueueDb _queue;
  final _uuid = const Uuid();

  @override
  Future<List<DriverAssignment>> listAssignments() async {
    try {
      final resp = await _client.dio.get<List<dynamic>>('/driver/assignments');
      return (resp.data ?? const [])
          .map((e) => DriverAssignment.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw NetworkFailure(e.message ?? 'Failed to fetch assignments');
    }
  }

  @override
  Future<String> updateAvailability(String status) async {
    try {
      final resp = await _client.dio.patch<Map<String, dynamic>>(
        '/driver/availability',
        data: {'availability_status': status},
      );
      return (resp.data?['availability_status'] ?? status).toString();
    } on DioException catch (e) {
      final detail = e.response?.data is Map ? (e.response!.data as Map)['detail'] : null;
      if (e.response?.statusCode == 409) {
        throw ConflictFailure(detail?.toString() ?? 'Cannot change availability right now.');
      }
      throw NetworkFailure(detail?.toString() ?? 'Failed to update availability.');
    }
  }

  @override
  Future<TripModel> acknowledge(String assignmentId) async {
    try {
      final resp = await _client.dio.post<Map<String, dynamic>>(
        '/driver/assignments/$assignmentId/ack',
      );
      return TripModel.fromJson(resp.data!);
    } on DioException catch (e) {
      throw NetworkFailure(e.message ?? 'Failed to acknowledge assignment');
    }
  }

  @override
  Future<void> decline(String assignmentId, String reason) async {
    try {
      await _client.dio.post<void>(
        '/driver/assignments/$assignmentId/decline',
        data: {'reason': reason.trim()},
      );
    } on DioException catch (e) {
      throw NetworkFailure(e.message ?? 'Failed to decline assignment');
    }
  }

  @override
  Future<TripModel> advanceMilestone({
    required String tripId,
    required String assignmentId,
    required String milestone,
    required double? lat,
    required double? lng,
    String? notes,
  }) async {
    final key = _uuid.v4();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final body = <String, dynamic>{
      'milestone': milestone,
      'occurred_at': nowIso,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
    try {
      final resp = await _client.dio.post<Map<String, dynamic>>(
        '/trips/$tripId/milestones',
        data: body,
        options: Options(headers: {'Idempotency-Key': key}),
      );
      return TripModel.fromJson(resp.data!);
    } on DioException catch (e) {
      if (e.response == null) {
        await _queue.enqueueTripAction(
          QueuedTripAction(
            idempotencyKey: key,
            assignmentId: assignmentId,
            actionType: 'milestone',
            payload: {'trip_id': tripId, ...body},
            occurredAtUtc: nowIso,
            createdAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
        return TripModel(id: tripId, assignmentId: assignmentId, status: milestone);
      }
      final detail = e.response?.data is Map ? (e.response!.data as Map)['detail'] : null;
      throw ValidationFailure(detail?.toString() ?? 'Milestone transition rejected.');
    }
  }

  @override
  Future<int> flushOfflineActions() async {
    final pending = await _queue.pendingTripActions();
    var synced = 0;
    for (final act in pending) {
      if (act.actionType == 'milestone') {
        final tripId = act.payload['trip_id'] as String;
        final body = Map<String, dynamic>.from(act.payload)..remove('trip_id');
        try {
          await _client.dio.post<void>(
            '/trips/$tripId/milestones',
            data: body,
            options: Options(headers: {'Idempotency-Key': act.idempotencyKey}),
          );
          await _queue.deleteTripAction(act.id!);
          synced++;
        } on DioException catch (e) {
          if (e.response == null) break;
          await _queue.deleteTripAction(act.id!);
        }
      }
    }
    return synced;
  }

  @override
  Future<TripModel> completeTrip({
    required String tripId,
    required int endOdometer,
    int waitingMinutes = 0,
    int extraChargesMinor = 0,
    String? notes,
  }) async {
    try {
      final resp = await _client.dio.post<Map<String, dynamic>>(
        '/trips/$tripId/complete',
        data: {
          'completed_at': DateTime.now().toUtc().toIso8601String(),
          'end_odometer': endOdometer,
          'waiting_minutes': waitingMinutes,
          'extra_charges_minor': extraChargesMinor,
          'currency': 'USD',
          if (notes != null && notes.isNotEmpty) 'completion_notes': notes,
        },
      );
      return TripModel.fromJson(resp.data!);
    } on DioException catch (e) {
      final detail = e.response?.data is Map ? (e.response!.data as Map)['detail'] : null;
      throw ValidationFailure(detail?.toString() ?? 'Trip completion failed.');
    }
  }

  @override
  Future<void> reportIncident({
    required String tripId,
    required String category,
    required String severity,
    required String description,
  }) async {
    try {
      await _client.dio.post<void>(
        '/trips/$tripId/incidents',
        data: {'category': category, 'severity': severity, 'description': description.trim()},
      );
    } on DioException catch (e) {
      throw NetworkFailure(e.message ?? 'Incident submission failed');
    }
  }
}
