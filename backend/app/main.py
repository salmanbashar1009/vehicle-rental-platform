"""FastAPI application factory and lifecycle management."""

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

import sentry_sdk
from fastapi import FastAPI

from app.api.v1.health import router as health_router
from app.api.v1.router import api_v1_router
from app.core.config import get_settings
from app.core.exceptions import register_exception_handlers
from app.core.logging import configure_logging, get_logger
from app.core.middleware import register_middleware
from app.core.redis_client import close_redis_client
from app.database.session import dispose_engine

logger = get_logger(__name__)


@asynccontextmanager
async def lifespan(_app: FastAPI) -> AsyncIterator[None]:
    """Startup and clean shutdown hooks."""
    logger.info("backend_starting")
    yield
    await close_redis_client()
    await dispose_engine()
    logger.info("backend_stopped")


def create_app() -> FastAPI:
    """Construct configured FastAPI application."""
    settings = get_settings()
    configure_logging("DEBUG" if settings.debug else "INFO")
    if settings.sentry_dsn:
        sentry_sdk.init(
            dsn=settings.sentry_dsn, send_default_pii=False, environment=settings.app_env
        )

    docs_url = "/docs" if settings.app_env != "production" else None
    openapi_url = "/openapi.json" if settings.app_env != "production" else None

    app = FastAPI(
        title=settings.app_name,
        version="1.0.0",
        docs_url=docs_url,
        redoc_url=None,
        openapi_url=openapi_url,
        lifespan=lifespan,
    )
    register_middleware(app, settings)
    register_exception_handlers(app)
    app.include_router(health_router)
    app.include_router(api_v1_router, prefix=settings.api_v1_prefix)
    return app


app = create_app()
