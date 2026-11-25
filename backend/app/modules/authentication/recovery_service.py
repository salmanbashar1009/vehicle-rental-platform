"""Password recovery service for single-use reset tokens."""

from datetime import UTC, datetime, timedelta

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ValidationDomainError
from app.core.security import generate_opaque_token, hash_password, hash_token
from app.modules.authentication.models import PasswordResetToken
from app.modules.authentication.repository import AuthRepository
from app.modules.authentication.schemas import PasswordResetConfirmRequest
from app.modules.users.repository import UserRepository


class RecoveryService:
    """Handles password reset token issuance and confirmation."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._users = UserRepository(session)
        self._auth = AuthRepository(session)

    async def request_password_reset(self, identifier: str) -> str | None:
        """Create a single-use 15m reset token (raw token returned for outbox/testing)."""
        user = await self._users.get_by_identifier(identifier)
        if user is None or not user.is_active:
            return None
        raw = generate_opaque_token()
        self._session.add(
            PasswordResetToken(
                user_id=user.id,
                token_hash=hash_token(raw),
                expires_at=datetime.now(UTC) + timedelta(minutes=15),
            )
        )
        await self._session.commit()
        return raw

    async def confirm_password_reset(self, payload: PasswordResetConfirmRequest) -> None:
        """Validate single-use token, update Argon2id hash, and revoke all sessions."""
        record = await self._auth.get_reset_token(hash_token(payload.token))
        now = datetime.now(UTC)
        if record is None or record.used_at is not None or record.expires_at <= now:
            raise ValidationDomainError("Password reset token is invalid or expired.")
        user = await self._users.get_by_id(record.user_id)
        if user is None:
            raise ValidationDomainError("Account no longer exists.")
        user.password_hash = hash_password(payload.new_password)
        record.used_at = now
        await self._auth.revoke_user_sessions(user.id)
        await self._session.commit()
