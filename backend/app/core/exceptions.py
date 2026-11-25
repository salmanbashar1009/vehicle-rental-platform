"""Centralized domain exceptions and safe JSON error response mapping."""

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from app.core.logging import get_logger

logger = get_logger(__name__)


class ErrorDetail(BaseModel):
    """Single field or reason detail in an API error payload."""

    field: str | None = None
    issue: str


class ErrorBody(BaseModel):
    """Standardized error envelope body."""

    code: str
    message: str
    details: list[ErrorDetail] = []
    correlation_id: str | None = None


class ErrorEnvelope(BaseModel):
    """Top-level error response envelope."""

    error: ErrorBody


class DomainError(Exception):
    """Base domain exception translated safely into an HTTP response."""

    status_code: int = status.HTTP_400_BAD_REQUEST
    code: str = "DOMAIN_ERROR"

    def __init__(
        self,
        message: str,
        *,
        code: str | None = None,
        status_code: int | None = None,
        details: list[ErrorDetail] | None = None,
    ) -> None:
        super().__init__(message)
        self.message = message
        if code is not None:
            self.code = code
        if status_code is not None:
            self.status_code = status_code
        self.details = details or []


class UnauthorizedError(DomainError):
    """Raised on missing, invalid, or expired authentication."""

    status_code = status.HTTP_401_UNAUTHORIZED
    code = "UNAUTHORIZED"


class ForbiddenError(DomainError):
    """Raised when an authenticated actor lacks permission or ownership."""

    status_code = status.HTTP_403_FORBIDDEN
    code = "FORBIDDEN"


class NotFoundError(DomainError):
    """Raised when a requested resource does not exist."""

    status_code = status.HTTP_404_NOT_FOUND
    code = "NOT_FOUND"


class ConflictError(DomainError):
    """Raised on duplicate keys, schedule overlaps, or idempotency mismatches."""

    status_code = status.HTTP_409_CONFLICT
    code = "RESOURCE_CONFLICT"


class ValidationDomainError(DomainError):
    """Raised on business validation violations (422)."""

    status_code = status.HTTP_422_UNPROCESSABLE_CONTENT
    code = "VALIDATION_ERROR"


class RateLimitError(DomainError):
    """Raised when rate limits or account lockouts trigger."""

    status_code = status.HTTP_429_TOO_MANY_REQUESTS
    code = "RATE_LIMITED"


def _correlation_id(request: Request) -> str | None:
    return getattr(request.state, "correlation_id", None)


def register_exception_handlers(app: FastAPI) -> None:
    """Attach global safe exception handlers to the FastAPI app."""

    @app.exception_handler(DomainError)
    async def _handle_domain(request: Request, exc: DomainError) -> JSONResponse:
        payload = ErrorEnvelope(
            error=ErrorBody(
                code=exc.code,
                message=exc.message,
                details=exc.details,
                correlation_id=_correlation_id(request),
            )
        )
        return JSONResponse(status_code=exc.status_code, content=payload.model_dump())

    @app.exception_handler(RequestValidationError)
    async def _handle_validation(request: Request, exc: RequestValidationError) -> JSONResponse:
        details = [
            ErrorDetail(
                field=".".join(str(part) for part in err.get("loc", []) if part != "body") or None,
                issue=str(err.get("msg", "invalid")),
            )
            for err in exc.errors()
        ]
        payload = ErrorEnvelope(
            error=ErrorBody(
                code="VALIDATION_ERROR",
                message="Request validation failed.",
                details=details,
                correlation_id=_correlation_id(request),
            )
        )
        return JSONResponse(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            content=payload.model_dump(),
        )

    @app.exception_handler(Exception)
    async def _handle_unexpected(request: Request, exc: Exception) -> JSONResponse:
        corr_id = _correlation_id(request)
        logger.exception("unhandled_exception", correlation_id=corr_id, exc_type=type(exc).__name__)
        payload = ErrorEnvelope(
            error=ErrorBody(
                code="INTERNAL_ERROR",
                message="An unexpected internal error occurred.",
                correlation_id=corr_id,
            )
        )
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content=payload.model_dump(),
        )
