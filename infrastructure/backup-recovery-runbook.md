# Deployment, Backup & Recovery Runbook

## 1. Local Development Startup (Docker Compose)
1. Copy `backend/.env.example` to `backend/.env` and replace placeholder secrets (`JWT_SECRET_KEY`, `S3_SECRET_KEY`).
2. Start core dependencies from `infrastructure/`:
   ```bash
   docker compose up -d postgres redis minio
   ```
3. Apply PostgreSQL migrations and seed 8 RBAC roles + 8 service categories:
   ```bash
   cd backend
   alembic upgrade head
   python scripts/seed.py
   uvicorn app.main:app --host 0.0.0.0 --port 8000
   ```
4. Verify probes: `GET http://localhost:8000/health/live` and `GET http://localhost:8000/health/ready`.

## 2. Database Backup Procedure (Production)
- **Automated Base + Logical Backups**:
  ```bash
  pg_dump --format=custom --no-owner --no-privileges "$DATABASE_URL" -f "velofleet_$(date -u +%Y%m%dT%H%M%SZ).dump"
  ```
- Encrypt dumps at rest using KMS/age before uploading to isolated backup object storage (`RPO <= 15m` with continuous WAL archiving).

## 3. Recovery & Verification Procedure
1. Provision a clean PostgreSQL 16 instance with `pgcrypto` and `btree_gist` extensions enabled.
2. Restore the dump (`pg_restore --clean --if-exists -d "$TARGET_DB" velofleet_*.dump`) or replay WAL to target timestamp.
3. Verify `alembic current`, run exclusion-constraint sanity checks (`excl_vehicle_schedule_no_overlap`, `excl_driver_schedule_no_overlap`), and validate `/health/ready` before shifting traffic.
