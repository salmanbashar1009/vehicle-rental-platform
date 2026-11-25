# Backend Engineering Instructions (`GEMINI.md`)

## 1. Project Overview & Role
Centralized backend for the Vehicle Rental, Booking, Dispatch & Fleet Management Platform. It is the **single source of truth** for business rules, pricing, resource availability, RBAC permissions, state transitions, financial ledgers, GPS ingestion, and audit logging across the Customer Website (Jaspr), Admin Dashboard (Flutter Windows), and Driver App (Flutter iOS/Android).

## 2. Mandatory Technology Stack
- **Language / Runtime**: Python 3.12+
- **Web Framework**: FastAPI (REST `/api/v1` + WebSockets `/api/v1/ws`), Uvicorn ASGI
- **Database & ORM**: PostgreSQL 16 (`btree_gist` extension), SQLAlchemy 2.x Async (`asyncpg`), Alembic
- **Validation & Settings**: Pydantic v2 (`ConfigDict(extra="forbid")` on write DTOs), `pydantic-settings`
- **Cache / Real-Time / Queue**: Redis 7 (`redis.asyncio` for rate limits, idempotency, latest GPS state, Pub/Sub)
- **Security & Auth**: `argon2-cffi` (Argon2id), `PyJWT`, `pyotp` (optional MFA), `cryptography`
- **Storage, Push & Observability**: `boto3` (S3/MinIO), `firebase-admin` (FCM), `structlog` (JSON logs), `sentry-sdk`

## 3. Architecture & Directory Structure
Modular monolith under `backend/app/`:
```
backend/app/
├── main.py                  # FastAPI factory, lifespan, middleware registration
├── core/                    # config, security, logging, exceptions, idempotency, rate_limit
├── database/                # async engine, session dependency, Base mixins, Alembic env
├── api/v1/                  # router registry + /health/live, /health/ready
├── modules/
│   ├── authentication/      # login, refresh rotation, lockout, recovery, MFA
│   ├── users/               # staff accounts, roles, permissions
│   ├── customers/           # customer profiles, corporate accounts
│   ├── services/            # 8 service categories, configurable workflows, pricing rules
│   ├── vehicles/            # fleet CRUD, documents, schedule blocks, maintenance
│   ├── drivers/             # driver profiles, licences, schedule blocks
│   ├── bookings/            # booking requests, stops, quotations, status history
│   ├── dispatch/            # eligible resource lookup, atomic assign/reassign
│   ├── trips/               # driver execution, milestones, completion, incidents
│   ├── tracking/            # GPS batch ingestion, Redis latest, WS fan-out, retention
│   ├── finance/             # invoices, immutable payments/refunds, expenses
│   ├── notifications/       # event outbox, in-app, FCM/email/SMS adapters
│   ├── reviews/             # post-trip customer ratings & moderation
│   ├── reports/             # operational/financial aggregations & CSV/PDF exports
│   └── audit/               # append-only audit trail service
├── integrations/            # s3_storage.py, fcm.py, email.py, sms.py
└── workers/                 # async background jobs (notifications, expiry, GPS purge)
```

## 4. Strict Coding, Layering & Naming Conventions
- **Layer Boundaries**: `router.py` (HTTP, auth deps, Pydantic DTOs) -> `service.py` (business logic, ACID transactions, audit/outbox) -> `repository.py` (SQLAlchemy queries). Never put SQL queries in routers; never raise `HTTPException` inside repositories or services (raise typed domain exceptions mapped centrally).
- **Never Expose ORM Models**: Always serialize responses through explicit Pydantic response schemas.
- **Cross-Module Isolation**: Modules call another module's public `service.py` interface; never mutate another module's ORM tables directly.
- **200-Line Hard Limit**: NO `.py`, `.md`, `.yml`, or config file may exceed 200 lines. Split large routers/services/models into sub-files cleanly by sub-domain.
- **Naming**: `snake_case` for Python modules/functions/JSON fields; `PascalCase` for classes/Pydantic schemas; `UPPER_SNAKE_CASE` for constants/enums where idiomatic.
- **Money & Time**: All monetary math uses `int` minor units (`BIGINT`, e.g., cents) or `Decimal` with explicit ISO-4217 `currency`; **never `float`**. All timestamps stored in UTC `TIMESTAMPTZ`.

## 5. Non-Negotiable Security & Integrity Rules
1. **Zero Double-Booking**: Confirmations, assignments, and maintenance blocks MUST insert/update `vehicle_schedule_blocks` / `driver_schedule_blocks` inside a single DB transaction guarded by PostgreSQL `EXCLUDE USING gist`.
2. **Backend-Enforced RBAC & Anti-IDOR**: Every route explicitly enforces role permissions or ownership (`booking.customer_id == actor.customer_id`, `assignment.driver_id == actor.driver_id`). Never trust client-supplied prices, roles, or user IDs.
3. **Secrets & Logging**: `.env.example` holds placeholders only. Never log passwords, JWTs, refresh tokens, or payment secrets.
4. **File Uploads**: Validate magic bytes + extension allowlist + `<= 10 MB`, generate UUID S3 keys, store sensitive files privately, serve via short-lived presigned URLs.
5. **No Architectural Shortcuts**: Never swallow exceptions, never leave commented-out code, never mark tasks `[x]` without running tests.

## 6. Development & Verification Commands
- Create venv & install: `python -m venv .venv && .\.venv\Scripts\pip install -r requirements-dev.txt`
- Run API locally: `uvicorn app.main:app --reload --port 8000`
- Lint & format check: `ruff check app tests && ruff format --check app tests`
- Type check: `mypy app`
- Security scan: `bandit -r app && pip-audit`
- Migrate DB: `alembic upgrade head`
- Run tests: `pytest -q`
- Export OpenAPI: `python scripts/export_openapi.py`
