# Backup, Recovery & Observability Plan

## Database Backup & Disaster Recovery

- **Automated Backups**: Daily encrypted logical + base backups (`pg_dump` / managed snapshot) plus continuous WAL archiving for Point-in-Time Recovery (PITR) in production.
- **Targets**: RPO <= 15 minutes, RTO <= 60 minutes.
- **Migration Safety**:
  - Run `alembic upgrade head` in staging before production.
  - Backup snapshot taken automatically prior to every production migration.
  - Only backward-compatible migrations (expand-and-contract) allowed for zero-downtime deploys.
- **Restore Drills**: Monthly automated restore test into an isolated verification database validating row counts and exclusion constraints.

## Observability Standards

- **Structured Logging**: JSON logs (`structlog`) with `timestamp_utc`, `level`, `service`, `correlation_id`, `actor_id` (UUID only), `module`, `event`, `duration_ms`. Strict redaction filter for tokens, passwords, and payment secrets.
- **Error Tracking**: Sentry SDK in FastAPI, Flutter Admin, Flutter Driver, and Jaspr client with PII scrubbing enabled.
- **Metrics & Health**:
  - `/health/live`: process liveness.
  - `/health/ready`: checks PostgreSQL `SELECT 1` + Redis `PING` + S3 bucket head.
  - Metrics tracked: API p95 latency, 5xx rate, DB pool saturation, WebSocket active connections, GPS batch ingestion rate, background job queue depth/failures.
