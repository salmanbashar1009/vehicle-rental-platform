"""Authentication business logic (login, refresh rotation, logout)."""

from datetime import UTC, datetime
from uuid import UUID, uuid4

import pyotp
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import RateLimitError, UnauthorizedError
from app.core.redis_client import enforce_rate_limit
from app.core.security import hash_token, verify_password
from app.modules.audit.service import AuditService
from app.modules.authentication.repository import AuthRepository
from app.modules.authentication.schemas import LoginRequest, TokenPairResponse
from app.modules.authentication.token_issuer import issue_session_tokens
from app.modules.users.repository import UserRepository


class AuthService:
    """Handles login throttling, MFA check, refresh token rotation, and logout."""

    def __init__(self, session: AsyncSession, redis: Redis | None = None) -> None:
        self._session = session
        self._redis = redis
        self._users = UserRepository(session)
        self._auth = AuthRepository(session)

    async def login(
        self,
        payload: LoginRequest,
        *,
        ip_address: str | None,
        user_agent: str | None,
        correlation_id: str | None,
    ) -> TokenPairResponse:
        """Authenticate credentials with Redis brute-force throttling and optional TOTP."""
        ident = payload.identifier.strip().lower()
        if self._redis is not None:
            await enforce_rate_limit(
                self._redis,
                key=f"rl:login:{ip_address or 'unknown'}:{ident}",
                max_attempts=5,
                window_seconds=600,
                message="Too many failed login attempts. Try again in 10 minutes.",
            )

        user = await self._users.get_by_identifier(payload.identifier)
        if user is None or not verify_password(payload.password, user.password_hash):
            AuditService.record(
                self._session,
                actor_id=user.id if user else None,
                actor_role="anonymous",
                action="auth.login_failed",
                resource_type="user",
                resource_id=ident,
                correlation_id=correlation_id,
                ip_address=ip_address,
            )
            await self._session.commit()
            raise UnauthorizedError("Invalid credentials.")

        if not user.is_active:
            raise UnauthorizedError("Account is disabled.")
        if user.locked_until and user.locked_until > datetime.now(UTC):
            raise RateLimitError("Account temporarily locked.")
        if (
            user.mfa_enabled
            and user.mfa_secret_enc
            and (
                not payload.totp_code
                or not pyotp.TOTP(user.mfa_secret_enc).verify(payload.totp_code, valid_window=1)
            )
        ):
            raise UnauthorizedError("Valid MFA verification code is required.")

        AuditService.record(
            self._session,
            actor_id=user.id,
            actor_role=user.roles[0].slug if user.roles else "user",
            action="auth.login_success",
            resource_type="user",
            resource_id=str(user.id),
            correlation_id=correlation_id,
            ip_address=ip_address,
        )
        pair = await issue_session_tokens(
            self._session,
            user,
            family_id=uuid4(),
            ip_address=ip_address,
            user_agent=user_agent,
        )
        await self._session.commit()
        return pair

    async def refresh(
        self,
        raw_refresh_token: str,
        *,
        ip_address: str | None,
        user_agent: str | None,
        correlation_id: str | None,
    ) -> TokenPairResponse:
        """Rotate refresh token; revoke entire family if reuse is detected."""
        session_row = await self._auth.get_session_by_hash(hash_token(raw_refresh_token))
        if session_row is None:
            raise UnauthorizedError("Invalid refresh token.")

        if session_row.rotated_at is not None:
            await self._auth.revoke_family(session_row.family_id)
            AuditService.record(
                self._session,
                actor_id=session_row.user_id,
                actor_role="user",
                action="auth.refresh_reuse_revoked",
                resource_type="auth_session",
                resource_id=str(session_row.family_id),
                correlation_id=correlation_id,
                ip_address=ip_address,
            )
            await self._session.commit()
            raise UnauthorizedError("Refresh token reuse detected; session family revoked.")

        now = datetime.now(UTC)
        if session_row.revoked_at is not None or session_row.expires_at <= now:
            raise UnauthorizedError("Refresh session expired or revoked.")

        user = await self._users.get_by_id(session_row.user_id)
        if user is None or not user.is_active:
            raise UnauthorizedError("User account is inactive.")

        session_row.rotated_at = now
        pair = await issue_session_tokens(
            self._session,
            user,
            family_id=session_row.family_id,
            ip_address=ip_address,
            user_agent=user_agent,
        )
        await self._session.commit()
        return pair

    async def logout(self, *, session_id: UUID, user_id: UUID) -> None:
        """Revoke active session on explicit logout."""
        await self._auth.revoke_session_by_id(session_id, user_id)
        await self._session.commit()
