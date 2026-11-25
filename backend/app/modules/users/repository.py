"""Repository for users and RBAC queries."""

from uuid import UUID

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.pagination import PaginationParams
from app.modules.users.models import Role, User


class UserRepository:
    """Data access methods for users and roles."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_id(self, user_id: UUID) -> User | None:
        """Fetch active non-deleted user by UUID."""
        stmt = select(User).where(User.id == user_id, User.deleted_at.is_(None))
        return (await self._session.execute(stmt)).scalar_one_or_none()

    async def get_by_identifier(self, identifier: str) -> User | None:
        """Fetch user by case-insensitive email or exact phone."""
        normalized = identifier.strip().lower()
        stmt = select(User).where(
            User.deleted_at.is_(None),
            or_(func.lower(User.email) == normalized, User.phone == identifier.strip()),
        )
        return (await self._session.execute(stmt)).scalar_one_or_none()

    async def exists_email_or_phone(self, email: str | None, phone: str | None) -> bool:
        """Check uniqueness of non-null email or phone."""
        filters = []
        if email:
            filters.append(func.lower(User.email) == email.strip().lower())
        if phone:
            filters.append(User.phone == phone.strip())
        if not filters:
            return False
        stmt = select(func.count(User.id)).where(or_(*filters))
        return int((await self._session.execute(stmt)).scalar_one()) > 0

    async def get_roles_by_slugs(self, slugs: list[str]) -> list[Role]:
        """Return roles matching provided slugs."""
        stmt = select(Role).where(Role.slug.in_(slugs))
        return list((await self._session.execute(stmt)).scalars().all())

    async def list_roles(self) -> list[Role]:
        """Return all configured RBAC roles."""
        stmt = select(Role).order_by(Role.name.asc())
        return list((await self._session.execute(stmt)).scalars().all())

    async def list_users(self, pagination: PaginationParams) -> tuple[list[User], int]:
        """Return paginated active users and total count."""
        base = select(User).where(User.deleted_at.is_(None))
        total = int(
            (
                await self._session.execute(
                    select(func.count(User.id)).where(User.deleted_at.is_(None))
                )
            ).scalar_one()
        )
        rows = (
            (
                await self._session.execute(
                    base.order_by(User.created_at.desc())
                    .offset(pagination.offset)
                    .limit(pagination.page_size)
                )
            )
            .scalars()
            .all()
        )
        return list(rows), total
