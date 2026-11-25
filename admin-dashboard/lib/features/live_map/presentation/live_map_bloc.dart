import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../domain/live_fleet_models.dart';

abstract class LiveMapEvent extends Equatable {
  const LiveMapEvent();
  @override
  List<Object?> get props => [];
}

class LiveMapStarted extends LiveMapEvent {
  const LiveMapStarted();
}

class LiveVehicleSelected extends LiveMapEvent {
  const LiveVehicleSelected(this.vehicle);
  final LiveFleetVehicle vehicle;
  @override
  List<Object?> get props => [vehicle];
}

class LiveTelemetryReceived extends LiveMapEvent {
  const LiveTelemetryReceived(this.payload);
  final Map<String, dynamic> payload;
  @override
  List<Object?> get props => [payload];
}

class LiveMapState extends Equatable {
  const LiveMapState({
    this.vehicles = const [],
    this.selected,
    this.playbackPolyline = const [],
    this.wsConnected = false,
    this.loading = false,
  });

  final List<LiveFleetVehicle> vehicles;
  final LiveFleetVehicle? selected;
  final List<LatLng> playbackPolyline;
  final bool wsConnected;
  final bool loading;

  LiveMapState copyWith({
    List<LiveFleetVehicle>? vehicles,
    LiveFleetVehicle? selected,
    List<LatLng>? playbackPolyline,
    bool? wsConnected,
    bool? loading,
  }) => LiveMapState(
    vehicles: vehicles ?? this.vehicles,
    selected: selected ?? this.selected,
    playbackPolyline: playbackPolyline ?? this.playbackPolyline,
    wsConnected: wsConnected ?? this.wsConnected,
    loading: loading ?? this.loading,
  );

  @override
  List<Object?> get props => [vehicles, selected, playbackPolyline, wsConnected, loading];
}

class LiveMapBloc extends Bloc<LiveMapEvent, LiveMapState> {
  LiveMapBloc(this._api, {this.connectWs = true}) : super(const LiveMapState()) {
    on<LiveMapStarted>(_onStarted);
    on<LiveVehicleSelected>(_onSelected);
    on<LiveTelemetryReceived>(_onTelemetry);
  }

  final ApiClient _api;
  final bool connectWs;
  WebSocket? _ws;

  Future<void> _onStarted(LiveMapStarted event, Emitter<LiveMapState> emit) async {
    emit(state.copyWith(loading: true));
    try {
      final resp = await _api.raw.get<List<dynamic>>('/tracking/fleet/live');
      final list = (resp.data ?? const [])
          .map((e) => LiveFleetVehicle.fromJson(e as Map<String, dynamic>))
          .toList();
      emit(state.copyWith(vehicles: list, loading: false));
    } catch (_) {
      emit(state.copyWith(loading: false));
    }
    if (connectWs && _ws == null) {
      await _openSocket(emit);
    }
  }

  Future<void> _openSocket(Emitter<LiveMapState> emit) async {
    try {
      final token = await _api.vault.readAccessToken();
      if (token == null) return;
      _ws = await WebSocket.connect(
        AppConfig.wsBaseUrl,
        headers: {'Authorization': 'Bearer $token'},
      );
      _ws!.add(jsonEncode({'type': 'subscribe', 'channel': 'admin:fleet'}));
      emit(state.copyWith(wsConnected: true));
      _ws!.listen((raw) {
        final msg = jsonDecode(raw.toString()) as Map<String, dynamic>;
        if (msg['type'] == 'vehicle.location' && msg['payload'] is Map<String, dynamic>) {
          add(LiveTelemetryReceived(msg['payload'] as Map<String, dynamic>));
        }
      }, onDone: () => _ws = null, onError: (_) => _ws = null);
    } catch (_) {
      emit(state.copyWith(wsConnected: false));
    }
  }

  Future<void> _onSelected(LiveVehicleSelected event, Emitter<LiveMapState> emit) async {
    emit(state.copyWith(selected: event.vehicle, playbackPolyline: const []));
    try {
      final res = await _api.raw.get<List<dynamic>>('/tracking/trips/${event.vehicle.tripId}/route');
      final pts = (res.data ?? const [])
          .map(
            (p) => LatLng(
              ((p as Map<String, dynamic>)['lat'] as num).toDouble(),
              (p['lng'] as num).toDouble(),
            ),
          )
          .toList();
      emit(state.copyWith(playbackPolyline: pts));
    } catch (_) {}
  }

  void _onTelemetry(LiveTelemetryReceived event, Emitter<LiveMapState> emit) {
    final vid = event.payload['vehicle_id']?.toString();
    if (vid == null) return;
    final updated = [
      for (final v in state.vehicles)
        v.vehicleId == vid ? v.applyLocationUpdate(event.payload) : v,
    ];
    LiveFleetVehicle? nextSelected = state.selected;
    if (nextSelected?.vehicleId == vid) {
      nextSelected = nextSelected!.applyLocationUpdate(event.payload);
    }
    emit(state.copyWith(vehicles: updated, selected: nextSelected));
  }

  @override
  Future<void> close() async {
    await _ws?.close();
    return super.close();
  }
}
