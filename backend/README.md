# VeloFleet Backend (FastAPI + PostgreSQL 16 + Redis 7)

Centralized modular-monolith API serving Customer Website, Admin Desktop Dashboard, and Driver Mobile App.

## Quick Start

1. Create and activate Python 3.12+ virtual environment:
   ```powershell
   python -m venv .venv
   .\.venv\Scripts\Activate.ps1
   pip install -r requirements-dev.txt
   ```
2. Start PostgreSQL 16, Redis 7, and MinIO via `infrastructure/docker-compose.yml`:
   ```powershell
   cd ..\infrastructure
   docker compose up -d postgres redis minio
   ```
3. Copy `.env.example` to `.env`, set secrets, then migrate and seed:
   ```powershell
   cd ..\backend
   alembic upgrade head
   python scripts\seed.py
   uvicorn app.main:app --reload --port 8000
   ```

## Verification Commands

- Line-limit guard (<= 200 lines): `python scripts\check_line_limits.py`
- Export OpenAPI contract: `python scripts\export_openapi.py`
- Lint & strict types: `ruff check app tests scripts && mypy app`
- Security scan: `bandit -r app -q`
- Automated tests: `pytest -v`
