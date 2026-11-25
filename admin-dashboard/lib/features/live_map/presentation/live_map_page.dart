import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/widgets/fleet_map_view.dart';
import '../../../core/widgets/status_badge.dart';
import 'live_map_bloc.dart';

/// Real-time OSM fleet tracking console with WebSocket updates and route playback.
class LiveFleetMapPage extends StatefulWidget {
  const LiveFleetMapPage({super.key});

  @override
  State<LiveFleetMapPage> createState() => _LiveFleetMapPageState();
}

class _LiveFleetMapPageState extends State<LiveFleetMapPage> {
  @override
  void initState() {
    super.initState();
    context.read<LiveMapBloc>().add(const LiveMapStarted());
  }

  Color _freshnessColor(String freshness) => switch (freshness) {
    'live' => const Color(0xFF15803D),
    'stale' => const Color(0xFFB45309),
    _ => const Color(0xFF64748B),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Fleet Monitoring'),
        actions: [
          IconButton(
            onPressed: () => context.read<LiveMapBloc>().add(const LiveMapStarted()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: BlocBuilder<LiveMapBloc, LiveMapState>(
        builder: (context, state) {
          final markers = <FleetMapMarker>[
            for (final v in state.vehicles)
              if (v.position != null)
                FleetMapMarker(
                  id: v.vehicleId,
                  position: v.position!,
                  label: v.vehiclePlate,
                  color: _freshnessColor(v.freshness),
                  onTap: () => context.read<LiveMapBloc>().add(LiveVehicleSelected(v)),
                ),
          ];
          final center = state.selected?.position ??
              (markers.isNotEmpty ? markers.first.position : const LatLng(23.8103, 90.4125));

          return Row(
            children: [
              SizedBox(
                width: 320,
                child: Column(
                  children: [
                    ListTile(
                      dense: true,
                      title: Text('Active Trips (${state.vehicles.length})'),
                      trailing: StatusBadge(status: state.wsConnected ? 'live' : 'stale'),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        itemCount: state.vehicles.length,
                        itemBuilder: (context, i) {
                          final v = state.vehicles[i];
                          return ListTile(
                            selected: state.selected?.vehicleId == v.vehicleId,
                            title: Text('${v.vehiclePlate} • ${v.vehicleName}'),
                            subtitle: Text('${v.driverName} (${v.tripStatus})'),
                            trailing: StatusBadge(status: v.freshness),
                            onTap: () => context.read<LiveMapBloc>().add(LiveVehicleSelected(v)),
                          );
                        },
                      ),
                    ),
                    if (state.selected != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        color: const Color(0xFFF1F5F9),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Inspector • ${state.selected!.bookingReference}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text('Driver: ${state.selected!.driverName}'),
                            Text('Trip Status: ${state.selected!.tripStatus}'),
                            Text(
                              'Speed: ${((state.selected!.speedMps ?? 0) * 3.6).toStringAsFixed(1)} km/h • '
                              'Route pts: ${state.playbackPolyline.length}',
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: FleetMapView(
                    center: center,
                    markers: markers,
                    polylinePoints: state.playbackPolyline,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
