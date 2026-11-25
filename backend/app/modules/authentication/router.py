"""FastAPI router for authentication endpoints."""

from fastapi import APIRouter, Depends, Request, Response, status
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.redis_client import get_redis_client
from app.database.session import get_db_session
from app.modules.authentication.dependencies import CurrentActor, get_current_actor
from app.modules.authentication.recovery_service import RecoveryService
from app.modules.authentication.registration_service import RegistrationService
from app.modules.authentication.schemas import (
    AuthUserSummary,
    LoginRequest,
    PasswordResetConfirmRequest,
    PasswordResetRequest,
    RefreshRequest,
    RegisterRequest,
    TokenPairResponse,
)
from app.modules.authentication.service import AuthService

router = APIRouter(prefix="/auth", tags=["Authentication"])


def _client_meta(request: Request) -> tuple[str | None, str | None, str | None]:
    ip = request.client.host if request.client else None
    ua = request.headers.get("user-agent")
    corr = getattr(request.state, "correlation_id", None)
    return ip, ua, corr


@router.post("/register", response_model=TokenPairResponse, status_code=status.HTTP_201_CREATED)
async def register(
    payload: RegisterRequest,
    request: Request,
    session: AsyncSession = Depends(get_db_session),
) -> TokenPairResponse:
    """Register a new customer account."""
    ip, ua, corr = _client_meta(request)
    return await RegistrationService(session).register_customer(
        payload, ip_address=ip, user_agent=ua, correlation_id=corr
    )


@router.post("/login", response_model=TokenPairResponse)
async def login(
    payload: LoginRequest,
    request: Request,
    session: AsyncSession = Depends(get_db_session),
    redis: Redis = Depends(get_redis_client),
) -> TokenPairResponse:
    """Authenticate user credentials and issue token pair."""
    ip, ua, corr = _client_meta(request)
    return await AuthService(session, redis=redis).login(
        payload, ip_address=ip, user_agent=ua, correlation_id=corr
    )


@router.post("/refresh", response_model=TokenPairResponse)
async def refresh_tokens(
    payload: RefreshRequest,
    request: Request,
    session: AsyncSession = Depends(get_db_session),
) -> TokenPairResponse:
    """Rotate refresh token and issue new access/refresh tokens."""
    ip, ua, corr = _client_meta(request)
    return await AuthService(session).refresh(
        payload.refresh_token, ip_address=ip, user_agent=ua, correlation_id=corr
    )


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(
    actor: CurrentActor = Depends(get_current_actor),
    session: AsyncSession = Depends(get_db_session),
) -> Response:
    """Revoke current authenticated session."""
    await AuthService(session).logout(session_id=actor.session_id, user_id=actor.user_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/me", response_model=AuthUserSummary)
async def me(actor: CurrentActor = Depends(get_current_actor)) -> AuthUserSummary:
    """Return authenticated user identity and effective RBAC permissions."""
    return AuthUserSummary(
        id=actor.user_id,
        email=actor.email,
        phone=actor.phone,
        full_name=actor.full_name,
        roles=sorted(actor.roles),
        permissions=sorted(actor.permissions),
        mfa_enabled=False,
    )


@router.post("/password-reset/request", status_code=status.HTTP_202_ACCEPTED)
async def request_password_reset(
    payload: PasswordResetRequest,
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, str]:
    """Initiate password recovery without disclosing account existence."""
    await RecoveryService(session).request_password_reset(payload.identifier)
    return {"message": "If an account exists, recovery instructions have been queued."}


@router.post("/password-reset/confirm", status_code=status.HTTP_204_NO_CONTENT)
async def confirm_password_reset(
    payload: PasswordResetConfirmRequest,
    session: AsyncSession = Depends(get_db_session),
) -> Response:
    """Complete password reset using a valid recovery token."""
    await RecoveryService(session).confirm_password_reset(payload)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
