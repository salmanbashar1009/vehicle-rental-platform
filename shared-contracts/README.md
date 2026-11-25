# Shared Contracts & Cross-Application Standards

This directory is the canonical cross-project contract hub synchronizing `backend`, `customer-website`, `admin-dashboard`, and `driver-app`.

## Index

| Document | Scope |
| --- | --- |
| [architecture-overview.md](architecture-overview.md) | System topology, component interactions, tech stack alignment |
| [erd-and-data-model.md](erd-and-data-model.md) | Core PostgreSQL entities, relationships, exclusion constraints |
| [api-contract-strategy.md](api-contract-strategy.md) | OpenAPI-first workflow, versioning, model generation/validation |
| [openapi-conventions.md](openapi-conventions.md) | Envelope, pagination, errors, idempotency, decimal money format |
| [websocket-protocol.md](websocket-protocol.md) | WS auth, channels, heartbeats, GPS/trip event payloads |
| [state-machines.md](state-machines.md) | Booking, quotation, assignment, trip, and maintenance lifecycles |
| [design-system.md](design-system.md) | Shared brand identity, UX rules per platform, component catalog |
| [design-tokens.md](design-tokens.md) | Canonical color palette, typography, spacing, radii, shadows |
| [security-baseline.md](security-baseline.md) | OWASP controls, Argon2id, JWT rotation, RBAC, GPS privacy |
| [open-decisions.md](open-decisions.md) | Unresolved business policies, safe defaults, documented assumptions |

## Synchronization Workflow

1. Any API schema, enum, or state transition change updates the relevant `shared-contracts/` document first.
2. Backend implements the FastAPI Pydantic schema and exports `/openapi.json` into `shared-contracts/openapi.json` (generated in Phase 1).
3. Client DTOs/models in Jaspr and Flutter are validated or generated against the exported OpenAPI schema in CI.
4. No breaking API changes are allowed inside `/api/v1`; introduce additive fields or `/api/v2`.
