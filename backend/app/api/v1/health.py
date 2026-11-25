"""Liveness and readiness probe endpoints."""

from fastapi import APIRouter, status
from fastapi.responses import JSONResponse
from sqlalchemy import text

from app.core.redis_client import get_redis_client
from app.database.session import get_session_factory

router = APIRouter(tags=["Health"])


@router.get("/health/live")
async def liveness() -> dict[str, str]:
    """Process liveness probe."""
    return {"status": "ok"}


@router.get("/health/ready")
async def readiness() -> JSONResponse:
    """Readiness probe verifying PostgreSQL and Redis connectivity."""
    checks: dict[str, str] = {}
    healthy = True
    try:
        async with get_session_factory()() as session:
            await session.execute(text("SELECT 1"))
        checks["postgres"] = "ok"
    except Exception:
        checks["postgres"] = "error"
        healthy = False

    try:
        pong = await get_redis_client().ping()
        checks["redis"] = "ok" if pong else "error"
        if not pong:
            healthy = False
    except Exception:
        checks["redis"] = "error"
        healthy = False

    code = status.HTTP_200_OK if healthy else status.HTTP_503_SERVICE_UNAVAILABLE
    return JSONResponse(
        status_code=code, content={"status": "ready" if healthy else "degraded", "checks": checks}
    )
