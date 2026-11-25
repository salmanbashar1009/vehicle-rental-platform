# Vehicle Rental, Booking, Dispatch & Fleet Management Platform

Production-grade platform for a chauffeur-driven vehicle rental and transportation business supporting tours, events, house shifting/cargo, airport transfers, corporate accounts, daily/weekly/monthly rentals, personal transport, and custom services.

## Repository Structure

| Directory | Stack | Purpose | Plans Entry |
| --- | --- | --- | --- |
| [backend](backend/plans/GEMINI.md) | Python, FastAPI, PostgreSQL, Redis | Modular monolith REST + WebSocket API | [backend/plans](backend/plans/requirements.md) |
| [customer-website](customer-website/plans/GEMINI.md) | Dart, Jaspr, Component CSS | SEO-first public website & customer portal | [customer-website/plans](customer-website/plans/requirements.md) |
| [admin-dashboard](admin-dashboard/plans/GEMINI.md) | Flutter Windows, BLoC, `flutter_map` | Enterprise fleet & dispatch desktop app | [admin-dashboard/plans](admin-dashboard/plans/requirements.md) |
| [driver-app](driver-app/plans/GEMINI.md) | Flutter iOS/Android, BLoC, `flutter_map` | Driver workflow & OS-compliant GPS app | [driver-app/plans](driver-app/plans/requirements.md) |
| [shared-contracts](shared-contracts/README.md) | OpenAPI, JSON schemas, Design Tokens | Single source of truth for contracts & UI | [API Strategy](shared-contracts/api-contract-strategy.md) |
| [infrastructure](infrastructure/README.md) | Docker, GitHub Actions, S3, Sentry | Environments, CI/CD, backups, observability | [Environments & CI](infrastructure/environments-and-ci.md) |

## Delivery Roadmap

1. **Phase 0 – Discovery & Architecture** *(Current)*: Specs, ERD, API contract strategy, design system, task breakdown.
2. **Phase 1 – Core MVP**: Auth, RBAC, catalogue, booking requests, quotations, conflict-free manual dispatch.
3. **Phase 2 – Driver Operations**: Driver auth, assignment ack, configurable trip milestones, completion, incidents.
4. **Phase 3 – GPS & Live Monitoring**: Background GPS buffering/ingestion, Redis Pub/Sub, WebSockets, live `flutter_map`.
5. **Phase 4 – Financial Management**: Deposits, immutable payment ledger, refunds, invoices, expenses, reconciliation.
6. **Phase 5 – Advanced Operations**: Maintenance schedules, CRM, corporate billing, automated reminders, analytics.

## Non-Negotiable Engineering Rules

- **Spec-Driven Development**: No feature code before updating `requirements.md`, `design.md`, `tasks.md`, and `tests.md`.
- **Strict 200-Line Limit**: No source, config, or documentation file may exceed 200 lines.
- **Backend Single Source of Truth**: Pricing, availability, RBAC, and state transitions are enforced server-side.
- **Zero-Conflict Dispatch**: PostgreSQL range exclusion constraints + row locking prevent double-booking vehicles/drivers.
- **Open Mapping**: `flutter_map` with configurable OSM-compatible tiles; never Google Maps Flutter SDK.
