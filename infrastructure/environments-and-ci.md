# Environments & CI/CD Pipeline Strategy

## Environment Matrix

| Environment | Purpose | Data & Integrations |
| --- | --- | --- |
| **Development** | Local Docker Compose | Local Postgres 16, Redis 7, MinIO, console email/SMS mock |
| **Staging** | Pre-prod QA & UAT | Managed Postgres + Redis, staging S3 bucket, sandbox payment/FCM |
| **Production** | Live operations | Managed HA Postgres (PITR), Redis TLS, S3 private buckets, Sentry |

## Configuration & Secret Rules

- All config injected via environment variables validated by Pydantic `BaseSettings`.
- `.env.example` committed with placeholder values only; `.env` gitignored.
- Staging/production secrets stored in cloud secrets manager / GitHub Actions Environments.
- Separate TLS certificates, DB credentials, JWT signing keys, and S3 buckets per environment.

## GitHub Actions CI/CD Workflows

1. **Line-Limit & Spec Guard** (every PR):
   - Verifies no `.py`, `.dart`, `.css`, `.html`, `.md`, `.yml` file exceeds 200 lines.
   - Verifies each subproject retains all 5 `plans/` documents.
2. **Backend CI**: `ruff check`, `mypy`, `bandit`, `pip-audit`, `pytest` (against PostgreSQL 16 + Redis 7 service containers), OpenAPI schema drift check.
3. **Jaspr Website CI**: `dart analyze`, `dart format --output=none --set-exit-if-changed`, `dart test`, Jaspr build verification.
4. **Admin & Driver Flutter CI**: `flutter analyze`, `dart format` check, `flutter test` (unit + BLoC + widget), Windows/Android/iOS build checks.
5. **Security & Release**: `gitleaks` secret scan; deploy to Staging on `main` merge after migration dry-run; manual approval gate for Production.
