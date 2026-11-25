"""Authentication and RBAC dependencies for FastAPI routes."""

from collections.abc import Callable
from dataclasses import dataclass
from uuid import UUID

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ForbiddenError, UnauthorizedError
from app.core.security import decode_access_token
from app.database.session import get_db_session
from app.modules.users.repository import UserRepository

_bearer = HTTPBearer(auto_error=False)


@dataclass(frozen=True)
class CurrentActor:
    """Verified authenticated actor extracted from JWT and active DB user."""

    user_id: UUID
    session_id: UUID
    roles: frozenset[str]
    permissions: frozenset[str]
    full_name: str
    email: str | None
    phone: str | None

    @property
    def primary_role(self) -> str:
        """Return deterministic primary role label for audit logs."""
        return sorted(self.roles)[0] if self.roles else "user"

    def has_permission(self, permission: str) -> bool:
        """Check permission or owner super-admin override."""
        return "owner" in self.roles or permission in self.permissions


async def get_current_actor(
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
    session: AsyncSession = Depends(get_db_session),
) -> CurrentActor:
    """Validate Bearer JWT and ensure user account remains active."""
    if creds is None or not creds.credentials:
        raise UnauthorizedError("Authentication credentials were not provided.")

    payload = decode_access_token(creds.credentials)
    try:
        user_id = UUID(str(payload["sub"]))
        session_id = UUID(str(payload["sid"]))
    except ValueError as exc:
        raise UnauthorizedError("Malformed authentication token claims.") from exc

    user = await UserRepository(session).get_by_id(user_id)
    if user is None or not user.is_active:
        raise UnauthorizedError("User account is inactive or no longer exists.")

    roles = frozenset(r.slug for r in user.roles)
    perms = frozenset(p.code for r in user.roles for p in r.permissions)
    return CurrentActor(
        user_id=user.id,
        session_id=session_id,
        roles=roles,
        permissions=perms,
        full_name=user.full_name,
        email=user.email,
        phone=user.phone,
    )


async def get_optional_actor(
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
    session: AsyncSession = Depends(get_db_session),
) -> CurrentActor | None:
    """Resolve authenticated actor when Bearer header is supplied, else None."""
    if creds is None or not creds.credentials:
        return None
    return await get_current_actor(creds=creds, session=session)


def require_permissions(*required: str) -> Callable[[CurrentActor], CurrentActor]:
    """Build dependency enforcing all required RBAC permissions."""

    async def _guard(actor: CurrentActor = Depends(get_current_actor)) -> CurrentActor:
        if "owner" in actor.roles:
            return actor
        missing = [perm for perm in required if perm not in actor.permissions]
        if missing:
            raise ForbiddenError("Insufficient permissions for this operation.")
        return actor

    return _guard  # type: ignore[return-value]


def require_roles(*allowed_roles: str) -> Callable[[CurrentActor], CurrentActor]:
    """Build dependency enforcing membership in at least one listed role."""

    async def _guard(actor: CurrentActor = Depends(get_current_actor)) -> CurrentActor:
        if "owner" in actor.roles:
            return actor
        if not actor.roles.intersection(allowed_roles):
            raise ForbiddenError("Role is not authorized for this resource.")
        return actor

    return _guard  # type: ignore[return-value]
