# Admin Dashboard Engineering Instructions (`GEMINI.md`)

## 1. Project Overview & Stack
Enterprise Windows desktop operations & fleet control center for VeloFleet staff (`owner`, `booking_manager`, `fleet_manager`, `dispatcher`, `accountant`, `customer_support`).
- **Framework**: Flutter `3.47+` targeting **Windows Desktop**
- **Architecture**: Feature-based Clean Architecture (`domain/`, `data/`, `presentation/`)
- **State Management**: BLoC (`flutter_bloc`, `equatable`)
- **Mapping**: `flutter_map` + `latlong2` with configurable OpenStreetMap-compatible tile provider & attribution (**NEVER Google Maps Flutter SDK**)
- **Networking & Storage**: `dio` (correlation ID, token refresh, idempotency), `web_socket_channel`, `flutter_secure_storage`, `go_router`

## 2. Feature-Based Clean Architecture Structure
```
admin-dashboard/lib/
├── main.dart
├── app.dart                         # MaterialApp.router, BrandThemeExtension, global BLoCs
├── core/
│   ├── config/                      # Env config (--dart-define API_URL, WS_URL, TILE_URL)
│   ├── di/                          # Dependency injection container
│   ├── error/                       # Typed Failure hierarchy & Dio exception mapper
│   ├── network/                     # Dio client, AuthInterceptor, WebSocketClient
│   ├── router/                      # GoRouter shell + RBAC route guards
│   ├── theme/                       # BrandThemeExtension matching design-tokens.md
│   └── widgets/                     # Desktop UI kit (DataTable, KpiCard, StatusBadge, Map)
└── features/
    ├── auth/                        # Login, refresh, session & permission context
    ├── dashboard/                   # KPIs, schedule, ops alerts, mini live map
    ├── bookings/                    # List, detail, manual create, quotes, timeline, notes
    ├── fleet/                       # Vehicles, docs, capacity, calendar, odometer
    ├── drivers/                     # Driver profiles, licences, availability, ratings
    ├── dispatch/                    # Split-pane resource allocation, conflicts, history
    ├── live_map/                    # Fleet map, marker inspector, routes, playback
    ├── finance/                     # Payments, deposits, refunds, invoices, expenses
    ├── maintenance/                 # Preventive schedules, repairs, auto-block
    ├── customers/                   # Individual & corporate CRM, negotiated rates
    ├── notifications/               # Alert center, urgent breakdown/incident toasts
    ├── reports/                     # Operational/financial analytics + CSV/PDF export
    └── users_roles/                 # Staff users & role assignment (Owner only)
```

## 3. Mandatory Engineering & Security Rules
1. **200-Line Hard Limit**: NO `.dart`, `.md`, `.yaml`, or config file may exceed 200 lines. Split tables, filters, forms, and dialogs into focused widgets.
2. **Zero Business Logic in Widgets**: Widgets only dispatch BLoC events and render explicit `Loading`, `Loaded`, `Empty`, `ActionInProgress`, `ActionFailure`, and `Failure` states.
3. **Backend Single Source of Truth**: Sidebar hides unauthorized sections for UX only; backend enforces all RBAC, availability conflicts, and monetary calculations.
4. **Desktop Ergonomics**: Resize-safe from `1024x700` to `4K`, collapsible sidebar, keyboard shortcuts (`Ctrl+K`, `Esc`, `F5`), sortable/paginated tables, confirmation dialogs with audit reason on destructive actions.
5. **Tile Compliance**: Centralize tile URL, API key, and attribution in `AppConfig` + `FleetMapView`.

## 4. Development & Verification Commands
- Install deps: `flutter pub get`
- Analyze & format: `flutter analyze && dart format --output=none --set-exit-if-changed .`
- Run tests: `flutter test`
- Run Windows app: `flutter run -d windows`
- Build Windows release: `flutter build windows --release`
