# Backend Implementation Tasks (Phases 2–5)

Continuation of [tasks.md](tasks.md). Each task requires unit/integration tests and <= 200-line files before marking `[x]`.

## Phase 2 – Driver Operations (`TRIP-*`, `NOTIF-*`)
- [x] `BE-201` Implement `trips` models & migrations (`trips`, `trip_status_events`, `incident_reports`) + workflow transition validator reading `service_workflows`. *Deps: BE-113*. *Test: `tests/test_trips_notifications.py`.*
- [x] `BE-202` Implement driver APIs: list own assignments, `acknowledge`/`decline` (reason + alert), milestone transitions (`Idempotency-Key`), trip completion (odometer, waiting, receipts, signature), and incident submission. *Deps: BE-201*. *Test: `tests/test_trips_notifications.py`.*
- [x] `BE-203` Implement `notifications` module (`notifications`, `notification_outbox`), FCM + SMTP + in-app worker with deduplication & exponential retry. *Deps: BE-202*. *Test: `tests/test_trips_notifications.py`.*

## Phase 3 – GPS & Live Monitoring (`GPS-*`)
- [x] `BE-301` Implement `tracking` batch GPS ingestion (`POST /tracking/locations/batch`) gated to active trip window + Redis latest state (`vehicle:latest:{id}`) + Redis Pub/Sub publish + rate limiting. *Deps: BE-202*. *Test: `tests/test_tracking_ws.py`.*
- [x] `BE-302` Implement WebSocket gateway (`/api/v1/ws`) with JWT handshake auth, per-channel RBAC/ownership checks, 25s ping/pong heartbeat, and Redis Pub/Sub fan-out. *Deps: BE-301*. *Test: `tests/test_tracking_ws.py`.*
- [x] `BE-303` Implement sampled `location_points` batch persistence, live fleet & customer tracking endpoints, admin route playback, stale/offline detector, and `gps_retention_days` purge worker. *Deps: BE-301*. *Test: `tests/test_tracking_ws.py`.*

## Phase 4 – Financial Management (`FIN-*`)
- [x] `BE-401` Implement `finance` models & migrations (`invoices`, `payments`, `refunds`, `expenses`) with `BIGINT` minor units and unique `idempotency_key`. *Deps: BE-112*. *Verified: `test_finance_units.py` & `test_finance_phase4.py`.*
- [x] `BE-402` Implement idempotent payment/deposit recording, reconciliation updates, refund approval workflow (`accountant`/`owner` + audit), and invoice/receipt PDF generator. *Deps: BE-401*. *Verified: `test_finance_phase4.py`.*
- [x] `BE-403` Implement trip/operating expense submission (driver + admin), receipt upload, approval workflow, and cash-flow vs recognized-revenue summary endpoint. *Deps: BE-401*. *Verified: `test_finance_phase4.py`.*

## Phase 5 – Advanced Operations (`MAINT-*`, `CRM-*`, `RPT-*`, `REV-*`)
- [x] `BE-501` Implement `maintenance` schedules/records with automatic `vehicle_schedule_blocks` locking + daily document/licence expiry reminder job. *Deps: BE-109*. *Verified: `test_phase5_ops.py`.*
- [x] `BE-502` Implement `corporate_accounts`, negotiated discounts, CRM customer communication logs, and outstanding corporate balance reports. *Deps: BE-401*. *Verified: `test_phase5_ops.py`.*
- [x] `BE-503` Implement dispatch scoring recommendations, post-trip `reviews` + moderation, and async CSV/PDF `reports` exports. *Deps: BE-402, BE-501*. *Verified: `test_phase5_ops.py`.*
