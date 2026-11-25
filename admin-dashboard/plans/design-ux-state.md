# Admin Dashboard Desktop UX, BLoC State & Map Design

## 1. BLoC State Architecture
Each feature BLoC keeps UI state predictable and flicker-free:
```dart
enum ViewStatus { initial, loading, loaded, empty, failure }
enum ActionStatus { idle, submitting, success, failure }
```
- **List/Detail BLoCs** maintain `viewStatus`, `items`, `pagination`, `filters`, `selectedItem`, `isRefreshing`, `actionStatus`, and `actionFailure` separately.
- **Benefit**: Submitting an assignment or quote (`ActionStatus.submitting`) never wipes out the currently visible table; a `409 Conflict` sets `ActionStatus.failure` with an inline alert banner while keeping the operator's filters intact.

## 2. Windows Desktop UX & Navigation Layout
- **Collapsible Sidebar**:
  - *Operations*: Dashboard, Bookings, Dispatch, Live Fleet Map
  - *Fleet & People*: Vehicles, Drivers, Maintenance, Customers
  - *Business*: Finance, Reports
  - *System*: Notifications, Users & Roles
  - Visibility filtered by `AuthSession.permissions`, backed by server enforcement.
- **Split-Pane & Drawer Workflows**:
  - **Bookings & Fleet**: Master paginated `EnterpriseDataTable` on the left + contextual slide-over detail drawer (`480px`) on the right.
  - **Dispatch**: Left column lists `Confirmed / Unassigned` bookings; right column shows eligible Vehicles & Drivers tabs with green `Eligible` / red `Conflict` / amber `Maintenance` badges.
- **Confirmation Dialogs**: `ConfirmActionDialog` displays impact summary + required/optional audit `reason` field before dispatching destructive API calls.

## 3. `flutter_map` Tile & Layer Design (`core/widgets/fleet_map_view.dart`)
- Uses `FlutterMap` with `TileLayer(urlTemplate: config.mapTileUrl, userAgentPackageName: 'com.velofleet.admin')` and mandatory `RichAttributionWidget`.
- **Layers**:
  1. `PolylineLayer`: Planned or active route segments between pickup, stops, and destination.
  2. `MarkerLayer` (Stops): Numbered stop pins (`P`, `1`, `2`, `D`).
  3. `MarkerLayer` (Vehicles): Status-colored vehicle pins with `live` (green dot), `stale` (amber dot), `offline` (red dot) halo + click-to-inspect side card (plate, driver name, booking ref, speed, `recorded_at` UTC/local).
