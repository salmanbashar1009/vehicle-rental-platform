"""Repository for auth sessions and password reset tokens."""

from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.authentication.models import AuthSession, PasswordResetToken


class AuthRepository:
    """Persistence helpers for refresh sessions and recovery tokens."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_session_by_hash(self, token_hash: str) -> AuthSession | None:
        """Fetch refresh session matching SHA-256 token hash."""
        stmt = select(AuthSession).where(AuthSession.refresh_token_hash == token_hash)
        return (await self._session.execute(stmt)).scalar_one_or_none()

    async def revoke_family(self, family_id: UUID) -> None:
        """Revoke all sessions belonging to a compromised token family."""
        stmt = (
            update(AuthSession)
            .where(AuthSession.family_id == family_id, AuthSession.revoked_at.is_(None))
            .values(revoked_at=datetime.now(UTC))
        )
        await self._session.execute(stmt)

    async def revoke_user_sessions(self, user_id: UUID) -> None:
        """Revoke all active refresh sessions for a user."""
        stmt = (
            update(AuthSession)
            .where(AuthSession.user_id == user_id, AuthSession.revoked_at.is_(None))
            .values(revoked_at=datetime.now(UTC))
        )
        await self._session.execute(stmt)

    async def revoke_session_by_id(self, session_id: UUID, user_id: UUID) -> None:
        """Revoke a specific session owned by user_id."""
        stmt = (
            update(AuthSession)
            .where(
                AuthSession.id == session_id,
                AuthSession.user_id == user_id,
                AuthSession.revoked_at.is_(None),
            )
            .values(revoked_at=datetime.now(UTC))
        )
        await self._session.execute(stmt)

    async def get_reset_token(self, token_hash: str) -> PasswordResetToken | None:
        """Fetch password reset record by token hash."""
        stmt = select(PasswordResetToken).where(PasswordResetToken.token_hash == token_hash)
        return (await self._session.execute(stmt)).scalar_one_or_none()
