# Infrastructure & Deployment Architecture

Covers containerized local development, staging/production topologies, CI/CD pipelines, backup/recovery, and observability.

## Index

| Document | Contents |
| --- | --- |
| [environments-and-ci.md](environments-and-ci.md) | Dev/staging/prod topology, Docker Compose, GitHub Actions gates |
| [backup-and-observability.md](backup-and-observability.md) | PostgreSQL backup/PITR, Sentry, structured JSON logs, metrics |

## Local Development Stack (Planned for Phase 1)

- `postgres`: `postgres:16-alpine` (with `btree_gist` enabled on init)
- `redis`: `redis:7-alpine` (AOF persistence optional in dev, Pub/Sub + rate-limit)
- `minio`: `minio/minio` (S3-compatible object storage for images/docs/receipts)
- `backend`: FastAPI + Uvicorn (multi-stage non-root Docker build)
- `worker`: Background job worker (notifications, expiry reminders, GPS flush/purge)
- `customer-website`: Jaspr SSR server / static+hydration container
