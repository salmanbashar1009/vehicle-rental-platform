# Backend Design (Entry Point)

## 1. System & Application Architecture
The backend is a **Modular Monolith** built with FastAPI + PostgreSQL 16 + Redis 7. It exposes REST APIs under `/api/v1`, WebSocket streams at `/api/v1/ws`, and unversioned probes `/health/live` and `/health/ready`.

### Supplementary Design Specifications
- [design-schema.md](design-schema.md) — Exact PostgreSQL tables, columns, indexes, `TSTZRANGE` exclusion constraints, soft deletes
- [design-api-contracts.md](design-api-contracts.md) — Complete REST endpoint inventory, RBAC dependencies, request/response schemas
- [design-security-realtime.md](design-security-realtime.md) — 8-role RBAC matrix, JWT/refresh rotation sequence, WebSocket & Redis GPS pipeline, workers
- [shared-contracts/openapi-conventions.md](../../shared-contracts/openapi-conventions.md) & [state-machines.md](../../shared-contracts/state-machines.md)

## 2. Module Boundaries & Dependency Flow
```
[FastAPI Routers (app/modules/*/router.py)]
       │ Pydantic v2 validation + RBAC / Ownership Depends()
       ▼
[Domain Services (app/modules/*/service.py)]
       │ Business rules + ACID asyncpg session + AuditService + Outbox
       ▼
[Repositories (app/modules/*/repository.py)]
       │ Parameterized SQLAlchemy 2.x queries + SELECT FOR UPDATE
       ▼
[PostgreSQL 16 (btree_gist)] ◄──► [Redis 7] ◄──► [S3 / FCM / SMTP]
```

**Boundary Rules**:
1. Routers NEVER import `sqlalchemy` or execute queries; they call `Service` methods and return Pydantic schemas.
2. Repositories NEVER commit transactions; `Service` (or FastAPI UoW dependency) owns `async with session.begin():`.
3. Cross-module communication uses explicit service interfaces (e.g., `dispatch.service` calls `audit.service.record()` and `notifications.service.enqueue()`) rather than reaching into foreign repositories.

## 3. Core Cross-Cutting Components (`app/core/`)
- `config.py`: Pydantic `BaseSettings` loading env vars (DB URL, Redis URL, JWT keys, S3 endpoint, CORS origins, default currency/timezone, rate limits).
- `exceptions.py`: Typed domain exceptions (`NotFoundError`, `ConflictError`, `ForbiddenError`, `ValidationDomainError`, `RateLimitError`, `UnauthorizedError`) mapped to standard JSON error envelope `{error: {code, message, details, correlation_id}}`.
- `middleware.py`: Assigns/propagates `X-Correlation-ID`, enforces request size limits, adds security headers (`X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`), logs request latency via `structlog`.
- `idempotency.py`: Helper hashing `(method, path, body)` keyed by `(actor_scope, idempotency_key)` in `idempotency_keys` table / Redis to prevent duplicate bookings, quote acceptances, payments, and GPS batches.

## 4. Key Architectural Decision Records (ADRs)
| ADR | Decision | Rationale |
| --- | --- | --- |
| `ADR-01` | Modular monolith over microservices | Eliminates distributed transaction complexity across booking/dispatch/finance while keeping clean module extraction seams. |
| `ADR-02` | PostgreSQL `EXCLUDE USING gist` on `TSTZRANGE` | Guarantees zero overlapping vehicle/driver reservations under parallel requests at the database engine level. |
| `ADR-03` | Integer minor units (`BIGINT`) + explicit `currency` | Eliminates floating-point rounding drift in quotes, invoices, taxes, and reconciliation. |
| `ADR-04` | Redis latest GPS + sampled Postgres `location_points` | Protects Postgres write throughput under live fleet tracking while keeping sub-second WebSocket fan-out. |
