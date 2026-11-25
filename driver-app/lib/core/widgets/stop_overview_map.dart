import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:velofleet_driver/core/config/app_config.dart';

/// Route stop coordinate model shared across assignment details and trip execution.
class StopCoordinate {
  const StopCoordinate({
    required this.seqOrder,
    required this.stopType,
    required this.address,
    this.lat,
    this.lng,
  });

  final int seqOrder;
  final String stopType;
  final String address;
  final double? lat;
  final double? lng;
}

/// Interactive stop overview map powered strictly by flutter_map + configurable OSM tiles.
class StopOverviewMap extends StatelessWidget {
  const StopOverviewMap({super.key, required this.stops, this.driverPosition});

  final List<StopCoordinate> stops;
  final LatLng? driverPosition;

  @override
  Widget build(BuildContext context) {
    final pts = <LatLng>[
      for (final s in stops)
        if (s.lat != null && s.lng != null) LatLng(s.lat!, s.lng!),
    ];
    final center = driverPosition ?? (pts.isNotEmpty ? pts.first : const LatLng(23.8103, 90.4125));

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 200,
        child: FlutterMap(
          options: MapOptions(initialCenter: center, initialZoom: 12),
          children: [
            TileLayer(
              urlTemplate: AppConfig.osmTileUrl,
              userAgentPackageName: 'com.velofleet.driver',
            ),
            if (pts.length >= 2)
              PolylineLayer(
                polylines: [Polyline(points: pts, strokeWidth: 4, color: const Color(0xFF0EA5E9))],
              ),
            MarkerLayer(
              markers: [
                for (final s in stops)
                  if (s.lat != null && s.lng != null)
                    Marker(
                      point: LatLng(s.lat!, s.lng!),
                      width: 34,
                      height: 34,
                      child: CircleAvatar(
                        backgroundColor: const Color(0xFF0F3D5E),
                        child: Text(
                          '${s.seqOrder}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                if (driverPosition != null)
                  Marker(
                    point: driverPosition!,
                    width: 36,
                    height: 36,
                    child: const Icon(Icons.directions_car, color: Color(0xFF15803D), size: 30),
                  ),
              ],
            ),
            const SimpleAttributionWidget(source: Text(AppConfig.tileAttribution)),
          ],
        ),
      ),
    );
  }
}
