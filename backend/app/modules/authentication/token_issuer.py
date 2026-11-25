"""Session token issuance helper for authentication service."""

from datetime import UTC, datetime, timedelta
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.security import create_access_token, generate_opaque_token, hash_token
from app.modules.authentication.models import AuthSession
from app.modules.authentication.schemas import AuthUserSummary, TokenPairResponse
from app.modules.users.models import User


async def issue_session_tokens(
    session: AsyncSession,
    user: User,
    *,
    family_id: UUID,
    ip_address: str | None,
    user_agent: str | None,
) -> TokenPairResponse:
    """Create AuthSession row and mint JWT access + opaque refresh token pair."""
    settings = get_settings()
    raw_refresh = generate_opaque_token()
    session_row = AuthSession(
        user_id=user.id,
        family_id=family_id,
        refresh_token_hash=hash_token(raw_refresh),
        expires_at=datetime.now(UTC) + timedelta(days=settings.refresh_token_expire_days),
        ip_address=ip_address,
        user_agent=user_agent[:255] if user_agent else None,
    )
    session.add(session_row)
    await session.flush()

    role_slugs = sorted({r.slug for r in user.roles})
    perm_codes = sorted({p.code for r in user.roles for p in r.permissions})
    access_token = create_access_token(
        user_id=user.id,
        roles=role_slugs,
        permissions=perm_codes,
        session_id=session_row.id,
    )
    return TokenPairResponse(
        access_token=access_token,
        refresh_token=raw_refresh,
        expires_in=settings.access_token_expire_minutes * 60,
        user=AuthUserSummary(
            id=user.id,
            email=user.email,
            phone=user.phone,
            full_name=user.full_name,
            roles=role_slugs,
            permissions=perm_codes,
            mfa_enabled=user.mfa_enabled,
        ),
    )
