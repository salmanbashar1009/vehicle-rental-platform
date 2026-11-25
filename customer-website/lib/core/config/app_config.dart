/// Runtime environment configuration for Customer Website.
class AppConfig {
  const AppConfig._();

  static const String brandName = 'VeloFleet';
  static const String siteUrl = String.fromEnvironment(
    'SITE_URL',
    defaultValue: 'http://localhost:8080',
  );
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8010/api/v1',
  );
  static const String wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'ws://localhost:8010/api/v1/ws',
  );
  static const String mapTileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );
  static const String supportPhone = '+1 (800) 555-0199';
  static const String supportEmail = 'reservations@velofleet.example';
}
