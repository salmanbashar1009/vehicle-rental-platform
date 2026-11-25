# Driver Application Testing & Verification Strategy

## 1. Tooling & Quality Gates
- **Framework**: `flutter_test`, `bloc_test`, `mocktail`, `sqflite_common_ffi`
- **Static Gates**: `flutter analyze` (zero warnings), `dart format --output=none --set-exit-if-changed .`, all files <= 200 lines.

## 2. Test Layers & Assertions
- **SQLite Queue & Sync Unit Tests (`sqflite_common_ffi`)**:
  - `pending_trip_actions` replays strictly in FIFO `created_at_ms` order preserving `Idempotency-Key`.
  - `pending_gps_points` caps at 5,000 rows, chunks batches of <= 20, and deletes rows only after `200`/`201` server ack.
  - Adaptive sampler drops redundant stationary pings inside 60s window.
- **BLoC Tests (`bloc_test`)**:
  - `HomeBloc`: prevents switching duty to `off_duty` while an active trip exists.
  - `TripBloc`: steps cleanly through standard 7-step flow AND House Shifting (`loading_started`/`loading_completed`, `unloading_started`/`unloading_completed`); handles offline enqueue cleanly.
  - `GpsTrackingBloc`: asserts location stream **starts ONLY on `en_route_to_pickup`** and **immediately stops + flushes on `service_completed` or `cancelled_or_exception`**.
- **Widget & Accessibility Tests**:
  - Pre-permission rationale screen renders before requesting OS permissions; denied state shows Settings button.
  - Primary milestone buttons meet `>= 48dp` height; `ConfirmMilestoneSheet` blocks accidental single-tap progression; `TrackingStatusBanner` renders `GPS Disabled`, `Permission Denied`, `Offline Buffering`, and `GPS Live`.
- **Platform & E2E Tests**:
  - Verify Android Foreground Service notification + iOS background permission flow on real device/emulator; verify offline airplane-mode milestone + GPS buffering -> reconnect sync matches backend state.

## 3. Requirement-to-Test Traceability
| Req IDs | Test Suite(s) |
| --- | --- |
| `DRV-AUTH-001..003` | `test/features/auth/auth_bloc_test.dart`, `test/features/auth/permission_rationale_test.dart` |
| `DRV-HOME-001`, `DRV-ASSIGN-001..002` | `test/features/home/home_bloc_test.dart`, `test/features/assignments/assignment_bloc_test.dart` |
| `DRV-TRIP-001..003`, `DRV-OPS-001..003` | `test/features/trip_execution/trip_bloc_test.dart`, `test/core/storage/offline_queue_test.dart` |
| `DRV-GPS-001..004` | `test/features/gps_tracking/gps_tracking_bloc_test.dart`, `test/features/gps_tracking/tracking_banner_test.dart` |
