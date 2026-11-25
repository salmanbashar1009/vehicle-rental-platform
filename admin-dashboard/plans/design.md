# Admin Dashboard Design (Entry Point)

## 1. Architecture Overview
Feature-based Clean Architecture Flutter Windows desktop application using `flutter_bloc` for predictable state transitions and `flutter_map` for open mapping.

### Supplementary Design Specs
- [design-ux-state.md](design-ux-state.md) — BLoC state pattern, desktop shell & shortcuts, data table/drawer patterns, `flutter_map` tile architecture
- [shared-contracts/design-system.md](../../shared-contracts/design-system.md) & [design-tokens.md](../../shared-contracts/design-tokens.md)

## 2. Clean Architecture Layering (Per Feature)
```
features/<feature>/
├── domain/
│   ├── entities/          # Pure Dart immutable business models (Equatable)
│   ├── repositories/      # Abstract interfaces returning Either<Failure, T> / Result<T>
│   └── usecases/          # Focused single-purpose operations where non-trivial
├── data/
│   ├── models/            # JSON DTOs matching shared-contracts/openapi.json + toEntity()
│   ├── datasources/       # Dio remote API calls (typed endpoints)
│   └── repositories/      # Concrete repository implementations + error mapping
└── presentation/
    ├── bloc/              # <feature>_event.dart, <feature>_state.dart, <feature>_bloc.dart
    ├── pages/             # Top-level desktop route pages (<= 200 lines)
    └── widgets/           # Modular panes, filter bars, forms, dialogs (<= 200 lines)
```

## 3. Core Infrastructure (`lib/core/`)
- `config/app_config.dart`: `--dart-define` environment values (`API_BASE_URL`, `WS_URL`, `MAP_TILE_URL`, `MAP_TILE_KEY`, `MAP_ATTRIBUTION`).
- `network/dio_client.dart`: Adds `X-Correlation-ID`, Bearer JWT header, single-flight token refresh lock on `401`, and `Idempotency-Key` on mutating requests.
- `network/ws_client.dart`: Authenticated WebSocket client subscribing to `admin:fleet`, managing 25s ping/pong heartbeat and exponential reconnect with REST snapshot heal.
- `router/app_router.dart`: `GoRouter` `ShellRoute` rendering the persistent collapsible desktop shell + role-based `redirect` guards.
- `theme/brand_theme.dart`: `ThemeData` + `BrandThemeExtension` implementing `#0F3D7A`, `#1D63DC`, `#0D9488`, `#F59E0B`, `#F8FAFC` canvas, `#FFFFFF` cards, semantic badges, and `Plus Jakarta Sans` / `Inter` / `JetBrains Mono`.
