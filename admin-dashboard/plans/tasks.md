# Admin Dashboard Implementation Tasks

Mark `[x]` only after implementation, `flutter analyze`, `flutter test`, and `<= 200`-line check pass.

## Phase 0 – Discovery & Architecture
- [x] `ADM-000` Create `admin-dashboard/plans/` (`GEMINI.md`, `requirements.md`, `req-modules.md`, `design.md`, `design-ux-state.md`, `tasks.md`, `tests.md`).

## Phase 1 – Core MVP
- [x] `ADM-101` Scaffold Flutter Windows app (`pubspec.yaml`, `BrandThemeExtension`, DI, `Failure` types, `DioClient` with single-flight JWT refresh + `Idempotency-Key`). *Deps: BE-101*. *Verified: `flutter analyze` & unit tests.*
- [x] `ADM-102` Build reusable desktop UI kit (`DesktopShell`, `KpiCard`, `StatusBadge`, `ConfirmActionDialog`, `EmptyStateView`, `ErrorStateView`, `FleetMapView`). *Deps: ADM-101*. *Verified: `widgets_test.dart`.*
- [x] `ADM-103` Implement `auth` feature (Login page, optional MFA input, `AuthBloc`, `flutter_secure_storage`, `GoRouter` RBAC guards). *Deps: BE-107, ADM-102*. *Verified: `bloc_and_unit_test.dart`.*
- [x] `ADM-104` Implement `dashboard` overview (fleet/driver/booking KPI cards, OSM `FleetMapView`). *Deps: BE-113, ADM-103*.
- [x] `ADM-105` Implement `bookings` feature (filtered list, itemized quotation dialog, confirm/cancel with audit reason). *Deps: BE-112, ADM-103*. *Verified: `BookingBloc` tests.*
- [x] `ADM-106` Implement `fleet` & `drivers` MVP (vehicle CRUD/table, driver directory, licence expiry badges). *Deps: BE-110, ADM-103*.
- [x] `ADM-107` Implement `dispatch` split-pane module (eligible vehicle/driver list with conflict badges, atomic assign/reassign, `409` recovery). *Deps: BE-113, ADM-105, ADM-106*. *Verified: `DispatchBloc` tests.*
- [x] `ADM-108` Implement `users_roles` module (Owner-only staff account directory & RBAC shell gate). *Deps: BE-107, ADM-103*. *Verified: `DesktopShell` RBAC test.*

## Phase 2–5 – Subsequent Enhancements
- [x] `ADM-201` Integrate `notifications` center + real-time assignment decline & driver incident urgent alerts. *Deps: BE-203*. *Verified: `phase2_3_test.dart`.*
- [x] `ADM-301` Implement `live_map` (`flutter_map` with configurable OSM tiles, WebSocket `admin:fleet`, marker inspector, freshness badges, stop polylines, historical playback). *Deps: BE-302, BE-303*. *Verified: `phase2_3_test.dart`.*
- [x] `ADM-401` Implement `finance` module (booking ledger, deposits/payments, refunds with approval reason, invoices/receipts, trip & operating expenses, reconciliation). *Deps: BE-402, BE-403*. *Verified: `phase4_finance_test.dart`.*
- [x] `ADM-501` Implement `maintenance` (schedules, logs, auto-blocking), `customers` CRM/corporate accounts, dispatch recommendations, and `reports` CSV/PDF exports. *Deps: BE-501..503*. *Verified: `phase5_ops_test.dart`.*
