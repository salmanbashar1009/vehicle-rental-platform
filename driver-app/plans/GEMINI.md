# Driver Application Engineering Instructions (`GEMINI.md`)

## 1. Project Overview & Stack
Mobile application for chauffeurs/drivers on **Android and iOS** focusing on safety, clarity, offline resilience, and OS-compliant authorized GPS tracking.
- **Framework**: Flutter `3.47+` (Android & iOS)
- **Architecture**: Feature-based Clean Architecture (`domain/`, `data/`, `presentation/`)
- **State Management**: BLoC (`flutter_bloc`, `equatable`)
- **Mapping & Nav**: `flutter_map` + `latlong2` with configurable OSM-compatible tiles (**NEVER Google Maps Flutter SDK**); external turn-by-turn navigation via OS intents (`url_launcher`)
- **GPS, Offline & Push**: `geolocator` / OS foreground service, `sqflite` / `drift` persistent queue, `connectivity_plus`, `firebase_messaging`, `flutter_secure_storage`

## 2. Clean Architecture Directory Structure
```
driver-app/lib/
├── main.dart
├── app.dart                         # MaterialApp.router, Light/Dark BrandTheme, global BLoCs
├── core/
│   ├── config/                      # API/WS URLs, OSM tile URL & key, GPS interval config
│   ├── di/                          # Dependency injection setup
│   ├── error/                       # Typed Failures (Network, Auth, Permission, Conflict)
│   ├── network/                     # Dio client, AuthInterceptor, Connectivity monitor
│   ├── storage/                     # SecureStorage (JWT) + SQLite local offline queue DB
│   ├── theme/                       # Light & Dark BrandThemeExtension tokens
│   └── widgets/                     # LargeTouchButton, StatusBanner, TrackingPill, StopMap
└── features/
    ├── auth/                        # Login, password recovery, profile, permission rationale
    ├── home/                        # Duty status toggle, current/upcoming/completed jobs
    ├── assignments/                 # Assignment detail, ack/decline, change/cancel alerts
    ├── trip_execution/              # Configurable milestone stepper, nav/call, completion
    ├── gps_tracking/                # Foreground/bg location service, buffer sync, health check
    └── incidents_expenses/          # Breakdown/emergency report, receipts, customer signature
```

## 3. Non-Negotiable Safety, Privacy & Engineering Rules
1. **200-Line Hard Limit**: NO `.dart`, `.md`, `.yaml`, or config file may exceed 200 lines.
2. **Stationary Safety First**: Minimum `48x48dp` touch targets, high contrast (Light & Dark themes), confirmation bottom sheet before irreversible milestone/incident actions, zero distracting interactions designed for driving.
3. **Strict GPS Privacy Window**: NEVER collect or transmit location outside an active authorized assignment (`en_route_to_pickup` through `service_completed`). Always show pre-permission disclosure and active tracking status indicator.
4. **Offline-First Sync**: Queue milestone transitions and GPS batches locally in SQLite with `Idempotency-Key` + UTC `recorded_at`; replay strictly in chronological order when online.
5. **No Secrets in Client**: Never commit signing keystores, `google-services.json` secrets, or hardcoded API keys.

## 4. Development & Verification Commands (Phase 2+)
- Install deps: `flutter pub get`
- Analyze & format: `flutter analyze && dart format --output=none --set-exit-if-changed .`
- Run tests: `flutter test`
- Run Android/iOS: `flutter run`
