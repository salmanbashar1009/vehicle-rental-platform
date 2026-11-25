"""HTTP middleware for correlation IDs, security headers, and body size guards."""

import time
import uuid
from collections.abc import Awaitable, Callable

import structlog
from fastapi import FastAPI, Request, Response, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.core.config import Settings
from app.core.exceptions import ErrorBody, ErrorEnvelope
from app.core.logging import get_logger

logger = get_logger(__name__)


def register_middleware(app: FastAPI, settings: Settings) -> None:
    """Attach correlation ID, security headers, body size guards, and outermost CORS."""

    @app.middleware("http")
    async def _security_and_correlation(
        request: Request,
        call_next: Callable[[Request], Awaitable[Response]],
    ) -> Response:
        corr_id = request.headers.get("X-Correlation-ID") or str(uuid.uuid4())
        request.state.correlation_id = corr_id
        structlog.contextvars.clear_contextvars()
        structlog.contextvars.bind_contextvars(correlation_id=corr_id)

        content_length = request.headers.get("content-length")
        if (
            content_length
            and content_length.isdigit()
            and int(content_length) > settings.max_request_body_bytes
        ):
            body = ErrorEnvelope(
                error=ErrorBody(
                    code="PAYLOAD_TOO_LARGE",
                    message="Request body exceeds allowed size limit.",
                    correlation_id=corr_id,
                )
            )
            return JSONResponse(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                content=body.model_dump(),
            )

        started = time.perf_counter()
        response = await call_next(request)
        duration_ms = round((time.perf_counter() - started) * 1000, 2)

        response.headers["X-Correlation-ID"] = corr_id
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        if settings.app_env == "production":
            response.headers["Strict-Transport-Security"] = "max-age=63072000; includeSubDomains"

        logger.info(
            "http_request",
            method=request.method,
            path=request.url.path,
            status_code=response.status_code,
            duration_ms=duration_ms,
        )
        return response

    dev_loopback_regex = (
        r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"
        if settings.app_env == "development"
        else None
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_allow_origins,
        allow_origin_regex=settings.cors_allow_origin_regex or dev_loopback_regex,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=[
            "Accept",
            "Authorization",
            "Content-Type",
            "Idempotency-Key",
            "X-Correlation-ID",
        ],
        expose_headers=["X-Correlation-ID"],
    )
