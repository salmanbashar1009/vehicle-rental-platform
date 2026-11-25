# API Contract Strategy

## Contract-First & OpenAPI Workflow

1. **Source of Truth**: FastAPI backend generates an OpenAPI 3.1 schema from strongly typed Pydantic v2 models, explicit response schemas, and documented error schemas.
2. **Artifact Export**: A CLI script (`backend/scripts/export_openapi.py`) exports `shared-contracts/openapi.json` whenever backend routes or schemas change.
3. **Client Synchronization**:
   - **Customer Website (Jaspr)** and **Admin/Driver Apps (Flutter)** maintain typed DTOs under `data/models/` matching `shared-contracts/openapi.json`.
   - CI validates that `shared-contracts/openapi.json` matches the live FastAPI app schema (`git diff --exit-code shared-contracts/openapi.json`).
   - API model drift checks run in CI to verify Dart/Flutter `fromJson`/`toJson` models match OpenAPI property names, types, and enums.

## API Versioning & Base Paths

- Base path: `/api/v1`
- Health checks (unversioned): `/health/live`, `/health/ready`
- OpenAPI docs (disabled or auth-gated in production): `/docs`, `/openapi.json`

## Domain Endpoint Groups (`/api/v1`)

| Prefix | Domain | Primary Consumers |
| --- | --- | --- |
| `/auth` | Login, refresh rotation, logout, MFA, recovery | All 3 clients |
| `/users`, `/roles` | Staff accounts, RBAC role & permission management | Admin |
| `/public/catalog` | Services, vehicles, availability hints, SEO metadata | Customer Website |
| `/customers`, `/corporate` | Customer profiles, corporate accounts, negotiated terms | Website, Admin |
| `/bookings` | Booking requests, timeline, reschedule, cancel, notes | Website, Admin |
| `/quotations` | Quote generation, itemized lines, accept/reject | Website, Admin |
| `/vehicles`, `/maintenance` | Fleet profiles, documents, schedule blocks, maintenance | Admin |
| `/drivers` | Driver profiles, licences, duty/availability status | Admin, Driver |
| `/dispatch` | Eligible resource recommendations, assign, reassign | Admin |
| `/trips` | Driver assignments, ack, milestones, completion, incidents | Driver, Admin, Website |
| `/tracking` | GPS batch ingestion, latest location, route history | Driver, Admin, Website |
| `/finance` | Payments, deposits, refunds, invoices, expenses, reconciliation | Admin, Website |
| `/notifications`, `/reports`, `/audit` | Alerts, CSV/PDF reports, immutable audit trail | Admin, Driver, Website |

## Security & Ownership Rules

- Every endpoint declares required RBAC permissions (`admin` roles) or resource ownership predicates (`customer` owns booking, `driver` owns active assignment).
- Never trust client-supplied prices, totals, statuses, or `customer_id`/`driver_id` overrides; derive actor identity strictly from verified JWT claims.
