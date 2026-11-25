"""FastAPI router for driver management."""

from uuid import UUID

from fastapi import APIRouter, Depends, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.pagination import PaginatedResponse, PaginationParams
from app.database.session import get_db_session
from app.modules.authentication.dependencies import CurrentActor, require_permissions
from app.modules.drivers.schemas import (
    DriverCreateRequest,
    DriverResponse,
    DriverUpdateRequest,
)
from app.modules.drivers.service import DriverService

router = APIRouter(prefix="/drivers", tags=["Drivers"])


@router.get("", response_model=PaginatedResponse[DriverResponse])
async def list_drivers(
    pagination: PaginationParams = Depends(),
    availability_status: str | None = None,
    _actor: CurrentActor = Depends(require_permissions("drivers.read")),
    session: AsyncSession = Depends(get_db_session),
) -> PaginatedResponse[DriverResponse]:
    """List fleet drivers."""
    return await DriverService(session).list_drivers(
        pagination, availability_status=availability_status
    )


@router.post("", response_model=DriverResponse, status_code=status.HTTP_201_CREATED)
async def create_driver(
    payload: DriverCreateRequest,
    request: Request,
    actor: CurrentActor = Depends(require_permissions("drivers.write")),
    session: AsyncSession = Depends(get_db_session),
) -> DriverResponse:
    """Create a driver profile and user account."""
    return await DriverService(session).create_driver(
        payload,
        actor_id=actor.user_id,
        actor_role=actor.primary_role,
        correlation_id=getattr(request.state, "correlation_id", None),
    )


@router.patch("/{driver_id}", response_model=DriverResponse)
async def update_driver(
    driver_id: UUID,
    payload: DriverUpdateRequest,
    request: Request,
    actor: CurrentActor = Depends(require_permissions("drivers.write")),
    session: AsyncSession = Depends(get_db_session),
) -> DriverResponse:
    """Update driver profile, licence, or availability."""
    return await DriverService(session).update_driver(
        driver_id,
        payload,
        actor_id=actor.user_id,
        actor_role=actor.primary_role,
        correlation_id=getattr(request.state, "correlation_id", None),
    )
