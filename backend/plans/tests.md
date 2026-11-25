# Backend Testing & QA Strategy

## 1. Test Environment & Tooling
- **Runner**: `pytest` + `pytest-asyncio` + `httpx.AsyncClient` (`ASGITransport`)
- **Database**: Real **PostgreSQL 16** test database (so `TSTZRANGE`, `EXCLUDE USING gist`, `CHECK`, and `SELECT FOR UPDATE` behave identically to production) + real **Redis 7** (or isolated Redis DB index cleared per test).
- **Static & Security Gates**: `ruff check`, `mypy app`, `bandit -r app`, `pip-audit`, `gitleaks`.

## 2. Test Layers & Required Assertions

### Unit Tests
- Argon2id hash & verify; JWT expiration & claim validation; minor-unit monetary arithmetic; state machine valid/invalid transition tables; pricing rule calculations; file magic-byte validator.

### Database Transaction & Concurrency Tests
- **Parallel Vehicle Double-Book**: Launch two concurrent `asyncio.gather` dispatch assignments targeting the same `vehicle_id` and overlapping `TSTZRANGE`. Assert **1 succeeds (`201`) and 1 fails (`409 RESOURCE_CONFLICT`)** via PostgreSQL exclusion constraint.
- **Parallel Driver Double-Book**: Same concurrency test for `driver_id`.
- **Maintenance Overlap**: Attempt booking confirmation or dispatch inside an active `maintenance` block; assert `409`.

### API Contract, Idempotency & Error Handling Tests
- Verify `extra="forbid"` rejects unknown fields (`422`), pagination bounds (`page_size <= 100`), correlation ID header echoed, and `Idempotency-Key` replay returns identical booking/payment while altered payload returns `409`.

### Security & Penetration-Oriented Tests
- **8-Role RBAC Matrix**: Automated parameterized test verifying every endpoint against all 8 roles (`200`/`201` for permitted, `403` for unauthorized).
- **IDOR / BOLA**: Customer A attempts `GET`/`POST` on Customer B's booking, quotation, invoice, and tracking WS -> assert `403`/`404`. Driver A attempts mutating Driver B's trip -> assert `403`.
- **Refresh Reuse Attack**: Replay an already-rotated refresh token -> assert `401` AND verify entire `family_id` is revoked.
- **Rate Limiting & Injection**: 6th bad login triggers `429`; SQL injection strings in search/filter params are safely parameterized; `.exe` renamed to `.png` fails magic-byte check.

### WebSocket, GPS & Performance Tests
- GPS batch upload rejected (`403`) before `en_route_to_pickup` and after `service_completed`; freshness flips `live` -> `stale` -> `offline`; WS rejects unauthenticated handshake (`4001`) and cross-customer booking subscriptions.

### End-to-End 14-Step Acceptance Flow
Automated E2E pytest executing steps 1–14 from PDF Section 9 / Master Prompt Section 12 (request -> quote -> accept -> confirm -> dispatch -> driver ack -> milestones -> GPS -> tracking -> completion -> payment/expense -> closure).

## 3. Requirement-to-Test Traceability Matrix
| Req IDs | Test Suite(s) |
| --- | --- |
| `AUTH-001..005`, `RBAC-001..002` | `test_auth.py`, `test_rbac_users.py` |
| `SVC-001..002`, `BOOK-001..005`, `QUOTE-001` | `test_services_catalog.py`, `test_bookings.py`, `test_quotations_confirm.py` |
| `FLEET-001..003`, `DRV-001..003`, `DISP-001..003` | `test_vehicles.py`, `test_drivers.py`, `test_dispatch_concurrency.py` |
| `TRIP-001..004`, `GPS-001..004`, `NOTIF-001..002` | `test_trip_workflows.py`, `test_gps_ingestion.py`, `test_websocket_tracking.py` |
| `FIN-001..005`, `MAINT-001..002`, `CRM-*`, `RPT-*`, `SEC-*` | `test_payments_refunds_invoices.py`, `test_maintenance_reminders.py`, `test_audit.py` |
