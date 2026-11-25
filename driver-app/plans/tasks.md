# Driver Application Implementation Tasks

Mark `[x]` only after implementation, `flutter analyze`, `flutter test`, and `<= 200`-line check pass.

## Phase 0 – Discovery & Architecture
- [x] `DRV-000` Create `driver-app/plans/` (`GEMINI.md`, `requirements.md`, `req-gps-workflow.md`, `design.md`, `design-gps-offline.md`, `tasks.md`, `tests.md`).

## Phase 2 – Driver Operations (Starts after Phase 1 Backend + `BE-201..203`)
- [x] `DRV-201` Scaffold Flutter mobile app (Android/iOS configs, Light/Dark `BrandThemeExtension`, DI, `DioClient`, `flutter_secure_storage`, `sqflite` local queue DB). *Deps: BE-114*. *Test: Queue DB & interceptor unit tests.*
- [x] `DRV-202` Implement `auth`, driver profile (licence expiry warnings), and OS permission rationale screens (`Location` + `Notifications`). *Deps: BE-107, DRV-201*. *Test: `AuthBloc` & permission rationale widget tests.*
- [x] `DRV-203` Implement `home` & `assignments` (FCM push handler, duty toggle guarded during active trip, job list, detail view, acknowledge/decline + reason). *Deps: BE-202, DRV-202*. *Test: `HomeBloc` & `AssignmentBloc` tests.*
- [x] `DRV-204` Implement `trip_execution` (configurable milestone stepper from `service_workflows`, `ConfirmMilestoneSheet`, `pending_trip_actions` offline FIFO sync). *Deps: BE-202, DRV-203*. *Test: Cargo vs Tour workflow & offline replay tests.*
- [x] `DRV-205` Implement `flutter_map` stop preview + external navigation intent (`url_launcher`), approved call button, `incidents_expenses` (incident photos, completion odometer/expenses/receipts/signature). *Deps: DRV-204*. *Test: Completion validation & incident alert tests.*

## Phase 3 – GPS & Live Monitoring (Starts after `BE-301..303`)
- [x] `DRV-301` Implement OS-compliant `gps_tracking` controller (Android Foreground Service + iOS background manager) strictly gated to `en_route_to_pickup`..`service_completed`. *Deps: BE-301, DRV-204*. *Test: Active-window start/stop invariant tests.*
- [x] `DRV-302` Implement adaptive battery sampling, `pending_gps_points` SQLite buffer, batch upload with `Idempotency-Key`, exponential backoff, and health banners (`gps_disabled`, `permission_denied`, `offline`, `stale`). *Deps: DRV-301*. *Test: Offline buffer flush & health state tests.*

## Phase 4–5 – Financial & Advanced Polish
- [x] `DRV-401` Add trip expense approval status history & driver allowance summary view. *Deps: BE-403*. *Verified: `driver_expenses_test.dart`.*
- [x] `DRV-501` Add driver performance summary & vehicle maintenance/expiry alerts for assigned vehicle. *Deps: BE-501*. *Verified: `driver_performance_test.dart`.*
