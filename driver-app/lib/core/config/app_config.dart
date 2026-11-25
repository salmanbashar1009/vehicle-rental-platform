/// Build-time configuration for VeloFleet Driver mobile application.
class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8010/api/v1',
  );

  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'ws://10.0.2.2:8010/api/v1/ws',
  );

  static const String osmTileUrl = String.fromEnvironment(
    'OSM_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  static const String tileAttribution = 'OpenStreetMap contributors';

  static const int movingDistanceFilterM = 25;
  static const int movingIntervalSec = 10;
  static const int stationaryIntervalSec = 60;
  static const int gpsMaxBatchSize = 20;
  static const int maxBufferedGpsPoints = 5000;
}
