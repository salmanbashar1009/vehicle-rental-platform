# Backend Implementation Tasks (Phase 0 & Phase 1)

Phases 2–5 are tracked in [tasks-phases-2-5.md](tasks-phases-2-5.md). Mark `[x]` **only after** implementation, lint/typecheck, and automated tests pass.

## Phase 0 – Discovery & Architecture
- [x] `BE-001` Inspect workspace, read Requirements v1.0 PDF, document gaps/open business decisions (`shared-contracts/open-decisions.md`).
- [x] `BE-002` Create `backend/plans/` with detailed `GEMINI.md`, `requirements.md`, `design.md`, `tasks.md`, `tests.md` + split specs (all <= 200 lines).
- [x] `BE-003` Define cross-project contracts (`erd-and-data-model.md`, `openapi-conventions.md`, `websocket-protocol.md`, `security-baseline.md`).

## Phase 1 – Core MVP

### 1.1 Foundation, Config, Database & Audit
- [x] `BE-101` Scaffold `backend/` (`pyproject.toml`, `requirements*.txt`, `.env.example`, `app/main.py`, `core/config.py`, `core/logging.py`, Dockerfile + `infrastructure/docker-compose.yml`). *Verified: `/health/live` test passes.*
- [x] `BE-102` Configure async SQLAlchemy 2.0 + `asyncpg` + Alembic (`0001`–`0003`) + Redis client + `/health/ready`. *Verified: live Postgres 16 migration & Redis ready.*
- [x] `BE-103` Implement `core/exceptions.py`, `X-Correlation-ID` & security headers middleware, CORS, and `idempotency_keys` helper. *Verified: `test_core_security.py`, `test_phase1_contracts.py`.*
- [x] `BE-104` Implement `audit` module (`audit_logs` model, migration, `AuditService.record()`, owner read endpoint). *Verified: live Postgres integration tests.*

### 1.2 Authentication, RBAC & Users (`AUTH-*`, `RBAC-*`)
- [x] `BE-105` Implement `users`, `roles`, `permissions`, `auth_sessions`, `password_reset_tokens` migrations & role/permission seed script (8 roles). *Verified: `scripts/seed.py` & `test_auth_rbac.py`.*
- [x] `BE-106` Implement Argon2id hashing, `/auth/register`, `/auth/login`, `/auth/refresh` (rotation + reuse revocation), `/auth/logout`, `/auth/me`, `/password-reset`. *Verified: `test_auth_rbac.py`.*
- [x] `BE-107` Implement RBAC dependencies (`require_permissions(...)`) + staff `/users` & `/roles` endpoints. *Verified: `test_auth_rbac.py`.*

### 1.3 Service Catalogue, Fleet & Drivers (`SVC-*`, `FLEET-*`, `DRV-*`)
- [x] `BE-108` Implement `services` module (`service_categories`, `service_workflows`, `pricing_rules`), seed 8 categories, `/public/catalog/services`. *Verified: `scripts/seed.py`.*
- [x] `BE-109` Implement `vehicles` module (`vehicles`, `vehicle_images`, `vehicle_documents`, `vehicle_schedule_blocks` with `EXCLUDE USING gist`), S3 upload validator, `/public/catalog/vehicles` + admin CRUD. *Verified: `test_dispatch_concurrency.py` & upload tests.*
- [x] `BE-110` Implement `drivers` module (`driver_profiles`, `driver_schedule_blocks` with `EXCLUDE USING gist`) + admin CRUD & availability APIs. *Verified: `test_dispatch_concurrency.py`.*

### 1.4 Customers, Bookings, Quotations & Manual Dispatch (`CUST-*`, `BOOK-*`, `QUOTE-*`, `DISP-*`)
- [x] `BE-111` Implement `customers` & `bookings` modules, idempotent submission, guest claim token, list/filter/detail, cancel/reschedule. *Verified: `test_auth_rbac.py`, `test_dispatch_concurrency.py`.*
- [x] `BE-112` Implement `quotations` module (itemized quote, validity expiry, accept/reject, admin confirm booking locking `vehicle_schedule_blocks`). *Verified: `test_dispatch_concurrency.py`.*
- [x] `BE-113` Implement `dispatch` module (`eligible-resources`, atomic `assign` & `reassign`, `assignments`, `assignment_history`). *Verified: `test_dispatch_concurrency.py` (13/13 pass).*
- [x] `BE-114` Export `shared-contracts/openapi.json` via `scripts/export_openapi.py`, run `ruff`, `mypy`, `bandit`, `check_line_limits.py`, and full `pytest` suite. *Verified: 13/13 passed.*
