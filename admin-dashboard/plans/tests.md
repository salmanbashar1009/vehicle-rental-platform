# Admin Dashboard Testing & Verification Strategy

## 1. Tooling & Quality Gates
- **Framework**: `flutter_test`, `bloc_test`, `mocktail`
- **Static Gates**: `flutter analyze` (zero warnings), `dart format --output=none --set-exit-if-changed .`, all files <= 200 lines.

## 2. Test Layers & Assertions
- **Unit & Data Layer Tests**:
  - Verify DTO `fromJson`/`toJson` compatibility against sample payloads from `shared-contracts/openapi.json`.
  - Verify `Dio` `AuthInterceptor` refreshes expired access token once across parallel `401` requests and logs out cleanly if refresh returns `401`.
  - Verify minor-unit money formatter (`15000` -> `$150.00`) without float rounding errors.
- **BLoC State Tests (`bloc_test`)**:
  - `AuthBloc`: login -> MFA challenge -> authenticated -> logout.
  - `BookingBloc`: load list -> filter -> create quote -> confirm booking (`ActionStatus.submitting` -> `success`) -> handle `409 RESOURCE_CONFLICT` without clearing table rows.
  - `DispatchBloc`: load eligible resources -> assign -> `409` refreshes eligible resources & emits conflict message.
  - `LiveMapBloc`: WebSocket `vehicle.location` updates vehicle marker coordinates and computes `live` / `stale` / `offline` states.
- **Widget & Desktop UX Tests**:
  - `DesktopShell` collapses sidebar cleanly without overflow at `1024x700` and `1920x1080`.
  - `EnterpriseDataTable` renders Loading skeleton, Empty CTA, Error retry, and triggers sort/page callbacks.
  - `ConfirmActionDialog` blocks submission when required audit reason is empty.
  - `FleetMapView` renders `FlutterMap` with tile URL + `RichAttributionWidget` + vehicle markers.
- **RBAC UI Gate Tests**:
  - Verify `Accountant` session hides `Users & Roles` and disables `Dispatch Assign`, while `Owner` sees full navigation.

## 3. Requirement-to-Test Traceability
| Req IDs | Test Suite(s) |
| --- | --- |
| `ADM-001`, `ADM-RBAC-001` | `test/features/auth/auth_bloc_test.dart`, `test/core/router_guard_test.dart` |
| `ADM-002..004` | `test/core/widgets/desktop_shell_test.dart`, `test/core/widgets/data_table_test.dart` |
| `ADM-BOOK-001`, `ADM-DISP-001` | `test/features/bookings/booking_bloc_test.dart`, `test/features/dispatch/dispatch_bloc_test.dart` |
| `ADM-FLEET-001`, `ADM-DRV-001` | `test/features/fleet/fleet_bloc_test.dart`, `test/features/drivers/driver_bloc_test.dart` |
| `ADM-005`, `ADM-MAP-001` | `test/features/live_map/live_map_bloc_test.dart`, `test/core/widgets/fleet_map_test.dart` |
