"""FastAPI router for staff user and role endpoints."""

from uuid import UUID

from fastapi import APIRouter, Depends, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.pagination import PaginatedResponse, PaginationParams
from app.database.session import get_db_session
from app.modules.authentication.dependencies import CurrentActor, require_permissions
from app.modules.users.schemas import (
    RoleResponse,
    UserCreateRequest,
    UserResponse,
    UserUpdateRequest,
)
from app.modules.users.service import UserService

router = APIRouter(tags=["Users & RBAC"])


@router.get("/roles", response_model=list[RoleResponse])
async def list_roles(
    _actor: CurrentActor = Depends(require_permissions("users.read")),
    session: AsyncSession = Depends(get_db_session),
) -> list[RoleResponse]:
    """List all RBAC roles."""
    return await UserService(session).list_roles()


@router.get("/users", response_model=PaginatedResponse[UserResponse])
async def list_users(
    pagination: PaginationParams = Depends(),
    _actor: CurrentActor = Depends(require_permissions("users.read")),
    session: AsyncSession = Depends(get_db_session),
) -> PaginatedResponse[UserResponse]:
    """List paginated staff/platform users."""
    return await UserService(session).list_users(pagination)


@router.post("/users", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def create_user(
    payload: UserCreateRequest,
    request: Request,
    actor: CurrentActor = Depends(require_permissions("users.write")),
    session: AsyncSession = Depends(get_db_session),
) -> UserResponse:
    """Create a staff user account."""
    return await UserService(session).create_staff_user(
        payload,
        actor_id=actor.user_id,
        actor_role=actor.primary_role,
        correlation_id=getattr(request.state, "correlation_id", None),
    )


@router.patch("/users/{user_id}", response_model=UserResponse)
async def update_user(
    user_id: UUID,
    payload: UserUpdateRequest,
    request: Request,
    actor: CurrentActor = Depends(require_permissions("users.write")),
    session: AsyncSession = Depends(get_db_session),
) -> UserResponse:
    """Update a user's active status, name, or roles."""
    return await UserService(session).update_user(
        user_id,
        payload,
        actor_id=actor.user_id,
        actor_role=actor.primary_role,
        correlation_id=getattr(request.state, "correlation_id", None),
    )
