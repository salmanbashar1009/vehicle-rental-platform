# Driver App Background GPS & Offline Sync Design

## 1. Authorized GPS Lifecycle State Machine
```
[Idle: Tracking Off]
   │  Trip enters `en_route_to_pickup` (from server or offline queue)
   │  AND Location Permission + GPS Sensor active
   ▼
[Tracking Active] ────(Network Offline)────▶ [Local SQLite Buffer]
   │                                                 │ (Online + Backoff)
   │  (GPS Turned Off / Permission Revoked)          ▼
   ├──▶ [Tracking Interrupted Banner]         [Batch Flush <=20 pts]
   │       └─ emit interruption flag when online
   │
   │  Trip reaches `service_completed` / `cancelled_or_exception`
   │  OR assignment reassigned/cancelled via push/poll
   ▼
[Final Buffer Flush] ──▶ [Stop Android Foreground / iOS Manager] ──▶ [Idle]
```

## 2. Android & iOS Platform Compliance
- **Android (`AndroidManifest.xml`)**:
  - `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION` (requested separately after in-app rationale), `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `POST_NOTIFICATIONS`.
  - Uses an explicit Foreground Service with persistent ongoing notification: *"VeloFleet Active Trip — Sharing authorized trip location"*.
- **iOS (`Info.plist`)**:
  - `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, `UIBackgroundModes` -> `location`.
  - Explicitly stops `CLLocationManager` updates the moment trip closes so blue background pill disappears.

## 3. Adaptive Battery Sampling & SQLite Schema
- **Adaptive Intervals**:
  - Moving (`speed_mps >= 1.5`): `distanceFilter = 25m`, min interval `10s`.
  - Stationary (`speed_mps < 1.5`): heartbeat every `60s` to prevent idle drain.
- **SQLite Tables (`local_queue_db.dart`)**:
  - `pending_trip_actions`: `id`, `idempotency_key` UNIQUE, `assignment_id`, `action_type`, `payload_json`, `occurred_at_utc`, `attempts`, `created_at_ms`.
  - `pending_gps_points`: `id`, `assignment_id`, `lat`, `lng`, `accuracy_m`, `speed_mps`, `heading_deg`, `recorded_at_utc`, `attempts` (FIFO cap 5,000 rows).
- **Sync Policy**: `SyncCoordinator` runs `pending_trip_actions` strictly FIFO first (so backend milestone opens tracking window), then flushes `pending_gps_points` in chunks of 20 with exponential backoff (`2s, 4s, 8s, max 60s`).
