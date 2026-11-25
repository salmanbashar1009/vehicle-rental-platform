import 'dart:async';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import 'package:velofleet_driver/core/config/app_config.dart';
import 'package:velofleet_driver/core/network/dio_client.dart';
import 'package:velofleet_driver/core/storage/local_queue_db.dart';
import 'package:velofleet_driver/features/assignments/domain/assignment_models.dart';

abstract class GpsTrackingEvent extends Equatable {
  const GpsTrackingEvent();
  @override
  List<Object?> get props => [];
}

/// Evaluates whether active trip milestone permits/requires background GPS.
class GpsTripWindowEvaluated extends GpsTrackingEvent {
  const GpsTripWindowEvaluated({required this.assignmentId, required this.tripStatus});
  final String? assignmentId;
  final String? tripStatus;
  @override
  List<Object?> get props => [assignmentId, tripStatus];
}

class GpsSampleCaptured extends GpsTrackingEvent {
  const GpsSampleCaptured({
    required this.lat,
    required this.lng,
    this.accuracyM,
    this.speedMps,
    this.headingDeg,
  });
  final double lat;
  final double lng;
  final double? accuracyM;
  final double? speedMps;
  final double? headingDeg;
  @override
  List<Object?> get props => [lat, lng, speedMps];
}

class GpsHealthChanged extends GpsTrackingEvent {
  const GpsHealthChanged(this.warning);
  final String? warning;
  @override
  List<Object?> get props => [warning];
}

class GpsBufferFlushRequested extends GpsTrackingEvent {
  const GpsBufferFlushRequested();
}

class GpsTrackingState extends Equatable {
  const GpsTrackingState({
    this.isActive = false,
    this.activeAssignmentId,
    this.bufferedCount = 0,
    this.healthWarning,
    this.intervalSec = AppConfig.stationaryIntervalSec,
  });

  final bool isActive;
  final String? activeAssignmentId;
  final int bufferedCount;
  final String? healthWarning;
  final int intervalSec;

  GpsTrackingState copyWith({
    bool? isActive,
    String? activeAssignmentId,
    bool clearAssignment = false,
    int? bufferedCount,
    String? healthWarning,
    bool clearWarning = false,
    int? intervalSec,
  }) => GpsTrackingState(
    isActive: isActive ?? this.isActive,
    activeAssignmentId: clearAssignment ? null : (activeAssignmentId ?? this.activeAssignmentId),
    bufferedCount: bufferedCount ?? this.bufferedCount,
    healthWarning: clearWarning ? null : (healthWarning ?? this.healthWarning),
    intervalSec: intervalSec ?? this.intervalSec,
  );

  @override
  List<Object?> get props => [isActive, activeAssignmentId, bufferedCount, healthWarning, intervalSec];
}

/// Strictly enforces the authorized GPS window: collects ONLY during active trip milestones.
class GpsTrackingBloc extends Bloc<GpsTrackingEvent, GpsTrackingState> {
  GpsTrackingBloc(this._client, this._queue) : super(const GpsTrackingState()) {
    on<GpsTripWindowEvaluated>(_onEvaluateWindow);
    on<GpsSampleCaptured>(_onSample);
    on<GpsHealthChanged>((e, emit) => emit(state.copyWith(healthWarning: e.warning, clearWarning: e.warning == null)));
    on<GpsBufferFlushRequested>(_onFlush);
  }

  final DriverDioClient _client;
  final LocalQueueDb _queue;
  final _uuid = const Uuid();

  Future<void> _onEvaluateWindow(
    GpsTripWindowEvaluated event,
    Emitter<GpsTrackingState> emit,
  ) async {
    final open =
        event.assignmentId != null &&
        event.tripStatus != null &&
        activeTrackingMilestones.contains(event.tripStatus);

    if (!open) {
      if (state.isActive) {
        add(const GpsBufferFlushRequested());
      }
      final cnt = await _queue.bufferedGpsCount();
      emit(state.copyWith(isActive: false, clearAssignment: true, bufferedCount: cnt));
      return;
    }

    final cnt = await _queue.bufferedGpsCount();
    emit(state.copyWith(isActive: true, activeAssignmentId: event.assignmentId, bufferedCount: cnt));
  }

  Future<void> _onSample(GpsSampleCaptured event, Emitter<GpsTrackingState> emit) async {
    if (!state.isActive || state.activeAssignmentId == null) {
      return; // Privacy hard guarantee: discard any sample when outside active trip window.
    }

    final moving = (event.speedMps ?? 0) >= 1.5;
    final nextInterval = moving ? AppConfig.movingIntervalSec : AppConfig.stationaryIntervalSec;

    await _queue.enqueueGpsPoint(
      QueuedGpsPoint(
        assignmentId: state.activeAssignmentId!,
        lat: event.lat,
        lng: event.lng,
        accuracyM: event.accuracyM,
        speedMps: event.speedMps,
        headingDeg: event.headingDeg,
        recordedAtUtc: DateTime.now().toUtc().toIso8601String(),
      ),
    );
    final count = await _queue.bufferedGpsCount();
    emit(state.copyWith(bufferedCount: count, intervalSec: nextInterval));
    add(const GpsBufferFlushRequested());
  }

  Future<void> _onFlush(GpsBufferFlushRequested event, Emitter<GpsTrackingState> emit) async {
    final batch = await _queue.peekGpsBatch();
    if (batch.isEmpty) return;

    final byAssignment = <String, List<QueuedGpsPoint>>{};
    for (final pt in batch) {
      byAssignment.putIfAbsent(pt.assignmentId, () => []).add(pt);
    }

    for (final entry in byAssignment.entries) {
      try {
        await _client.dio.post<void>(
          '/tracking/locations/batch',
          data: {
            'assignment_id': entry.key,
            'points': entry.value.map((p) => p.toApiJson()).toList(),
            if (state.healthWarning != null) 'interruption_status': state.healthWarning,
          },
          options: Options(headers: {'Idempotency-Key': _uuid.v4()}),
        );
        await _queue.deleteGpsPoints([for (final p in entry.value) if (p.id != null) p.id!]);
      } on DioException catch (e) {
        if (e.response?.statusCode == 403) {
          await _queue.deleteGpsPoints([for (final p in entry.value) if (p.id != null) p.id!]);
        }
        break;
      }
    }
    final remaining = await _queue.bufferedGpsCount();
    emit(state.copyWith(bufferedCount: remaining));
  }
}
