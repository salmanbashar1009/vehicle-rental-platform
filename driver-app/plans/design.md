# Driver Application Design (Entry Point)

## 1. Architecture Overview
Feature-based Clean Architecture Flutter mobile app (`domain/`, `data/`, `presentation/`) using `flutter_bloc`, `flutter_map`, and an offline-first SQLite synchronization layer.

### Supplementary Design Specs
- [design-gps-offline.md](design-gps-offline.md) — Authorized GPS state machine, Android/iOS OS compliance, adaptive sampling, SQLite FIFO sync queue
- [shared-contracts/design-system.md](../../shared-contracts/design-system.md) & [design-tokens.md](../../shared-contracts/design-tokens.md)

## 2. Core Infrastructure (`lib/core/`)
- `config/app_config.dart`: Build-time `--dart-define` API/WS URLs, OSM tile URL/key, GPS sampling intervals.
- `network/dio_client.dart`: `X-Correlation-ID`, Bearer JWT header, single-flight refresh token lock, connectivity awareness.
- `storage/local_queue_db.dart`: `sqflite` database storing `pending_trip_actions` and `pending_gps_points` for offline resilience.
- `theme/brand_theme.dart`: Light (`#F8FAFC` / `#FFFFFF`) and Night-Driving Dark (`#0B1220` / `#162033`) themes sharing VeloFleet semantic status tokens.
- `widgets/`:
  - `LargeTouchButton` (`minHeight: 54`), `TrackingStatusBanner`, `OfflineSyncBadge`, `ConfirmMilestoneSheet`, `StopOverviewMap` (`flutter_map`).

## 3. Mobile UX & Safety Ergonomics
1. **3-Tab Bottom Navigation**: `Home` (Duty + Active Job), `Schedule` (Upcoming & Completed), `Profile` (Licence, Vehicle, Settings/Theme).
2. **Focused Active Trip Cockpit**: When a trip is active, Home elevates a single prominent card showing current stop, `Navigate` + `Call` quick actions, `TrackingPill` (`GPS Live` / `Buffering` / `GPS Off`), and one full-width primary milestone button gated by `ConfirmMilestoneSheet`.
3. **Accessible Night Mode**: Manual toggle + system follow for night driving without harsh white screen glare.
