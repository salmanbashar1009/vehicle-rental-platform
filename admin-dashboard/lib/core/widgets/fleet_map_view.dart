import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';

/// Represents a live or planned marker displayed on FleetMapView.
class FleetMapMarker {
  const FleetMapMarker({
    required this.id,
    required this.position,
    required this.label,
    required this.color,
    this.onTap,
  });

  final String id;
  final LatLng position;
  final String label;
  final Color color;
  final VoidCallback? onTap;
}

/// OpenStreetMap-compatible flutter_map wrapper (NO Google Maps SDK).
class FleetMapView extends StatelessWidget {
  const FleetMapView({
    this.center = const LatLng(23.8103, 90.4125),
    this.zoom = 12.0,
    this.markers = const [],
    this.polylinePoints = const [],
    this.tileProvider,
    super.key,
  });

  final LatLng center;
  final double zoom;
  final List<FleetMapMarker> markers;
  final List<LatLng> polylinePoints;
  final TileProvider? tileProvider;

  @override
  Widget build(BuildContext context) {
    final url = AppConfig.mapTileApiKey.isNotEmpty
        ? '${AppConfig.mapTileUrlTemplate}?api_key=${AppConfig.mapTileApiKey}'
        : AppConfig.mapTileUrlTemplate;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: FlutterMap(
        options: MapOptions(initialCenter: center, initialZoom: zoom),
        children: [
          TileLayer(
            urlTemplate: url,
            userAgentPackageName: 'com.velofleet.admin',
            tileProvider: tileProvider ?? NetworkTileProvider(),
          ),
          if (polylinePoints.length >= 2)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: polylinePoints,
                  strokeWidth: 4.0,
                  color: const Color(0xFF1D63DC),
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              for (final m in markers)
                Marker(
                  point: m.position,
                  width: 96,
                  height: 44,
                  child: GestureDetector(
                    onTap: m.onTap,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: m.color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            m.label,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.location_on, color: m.color, size: 20),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          RichAttributionWidget(
            attributions: [TextSourceAttribution(AppConfig.mapAttribution)],
          ),
        ],
      ),
    );
  }
}
