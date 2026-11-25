"""Staff user and RBAC management service."""

from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, NotFoundError, ValidationDomainError
from app.core.pagination import PaginatedResponse, PaginationParams
from app.core.security import hash_password
from app.modules.audit.service import AuditService
from app.modules.users.models import User
from app.modules.users.repository import UserRepository
from app.modules.users.schemas import (
    RoleResponse,
    UserCreateRequest,
    UserResponse,
    UserUpdateRequest,
)


class UserService:
    """Business operations for staff accounts and role assignments."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._repo = UserRepository(session)

    async def list_users(self, pagination: PaginationParams) -> PaginatedResponse[UserResponse]:
        """Return paginated users."""
        users, total = await self._repo.list_users(pagination)
        return PaginatedResponse.create(
            items=[UserResponse.model_validate(u) for u in users],
            page=pagination.page,
            page_size=pagination.page_size,
            total_items=total,
        )

    async def list_roles(self) -> list[RoleResponse]:
        """Return all system roles."""
        roles = await self._repo.list_roles()
        return [RoleResponse.model_validate(r) for r in roles]

    async def create_staff_user(
        self,
        payload: UserCreateRequest,
        *,
        actor_id: UUID,
        actor_role: str,
        correlation_id: str | None,
    ) -> UserResponse:
        """Create a staff user with validated roles and audit trail."""
        if not payload.email and not payload.phone:
            raise ValidationDomainError("Either email or phone is required.")
        email = payload.email.lower() if payload.email else None
        if await self._repo.exists_email_or_phone(email, payload.phone):
            raise ConflictError("User with this email or phone already exists.")

        roles = await self._repo.get_roles_by_slugs(payload.role_slugs)
        if len(roles) != len(set(payload.role_slugs)):
            raise ValidationDomainError("One or more role slugs are invalid.")

        user = User(
            email=email,
            phone=payload.phone.strip() if payload.phone else None,
            full_name=payload.full_name.strip(),
            password_hash=hash_password(payload.password),
            roles=roles,
        )
        self._session.add(user)
        await self._session.flush()
        AuditService.record(
            self._session,
            actor_id=actor_id,
            actor_role=actor_role,
            action="user.created",
            resource_type="user",
            resource_id=str(user.id),
            after_state={"roles": [r.slug for r in roles], "is_active": user.is_active},
            correlation_id=correlation_id,
        )
        await self._session.commit()
        await self._session.refresh(user)
        return UserResponse.model_validate(user)

    async def update_user(
        self,
        user_id: UUID,
        payload: UserUpdateRequest,
        *,
        actor_id: UUID,
        actor_role: str,
        correlation_id: str | None,
    ) -> UserResponse:
        """Update staff active state, name, or roles with audit trail."""
        user = await self._repo.get_by_id(user_id)
        if user is None:
            raise NotFoundError("User not found.")

        before = {"is_active": user.is_active, "roles": [r.slug for r in user.roles]}
        if payload.full_name is not None:
            user.full_name = payload.full_name.strip()
        if payload.is_active is not None:
            user.is_active = payload.is_active
        if payload.role_slugs is not None:
            roles = await self._repo.get_roles_by_slugs(payload.role_slugs)
            if len(roles) != len(set(payload.role_slugs)):
                raise ValidationDomainError("One or more role slugs are invalid.")
            user.roles = roles

        await self._session.flush()
        AuditService.record(
            self._session,
            actor_id=actor_id,
            actor_role=actor_role,
            action="user.updated",
            resource_type="user",
            resource_id=str(user.id),
            before_state=before,
            after_state={"is_active": user.is_active, "roles": [r.slug for r in user.roles]},
            reason=payload.reason,
            correlation_id=correlation_id,
        )
        await self._session.commit()
        await self._session.refresh(user)
        return UserResponse.model_validate(user)
