"""Public and admin vehicle fleet FastAPI routers."""

from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Depends, File, Form, Request, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.pagination import PaginatedResponse, PaginationParams
from app.database.session import get_db_session
from app.integrations.s3_storage import S3StorageClient
from app.modules.authentication.dependencies import CurrentActor, require_permissions
from app.modules.vehicles.media_service import VehicleMediaService
from app.modules.vehicles.schemas import (
    ScheduleBlockResponse,
    VehicleCreateRequest,
    VehicleImageResponse,
    VehicleResponse,
    VehicleUpdateRequest,
)
from app.modules.vehicles.service import VehicleService

public_router = APIRouter(prefix="/public/catalog/vehicles", tags=["Public Catalogue"])
admin_router = APIRouter(prefix="/vehicles", tags=["Fleet Management"])


@public_router.get("", response_model=PaginatedResponse[VehicleResponse])
async def list_public_vehicles(
    pagination: PaginationParams = Depends(),
    category: str | None = None,
    min_seats: int | None = None,
    max_rate_minor: int | None = None,
    facility: str | None = None,
    start_at: datetime | None = None,
    end_at: datetime | None = None,
    session: AsyncSession = Depends(get_db_session),
) -> PaginatedResponse[VehicleResponse]:
    """Browse public vehicle catalogue with optional filters and availability check."""
    return await VehicleService(session).list_vehicles(
        pagination=pagination,
        category=category,
        min_seats=min_seats,
        max_rate_minor=max_rate_minor,
        facility=facility,
        start_at=start_at,
        end_at=end_at,
        public_only=True,
    )


@public_router.get("/{vehicle_id}", response_model=VehicleResponse)
async def get_public_vehicle(
    vehicle_id: UUID, session: AsyncSession = Depends(get_db_session)
) -> VehicleResponse:
    """View public vehicle detail."""
    return await VehicleService(session).get_vehicle(vehicle_id, public_only=True)


@admin_router.get("", response_model=PaginatedResponse[VehicleResponse])
async def list_admin_vehicles(
    pagination: PaginationParams = Depends(),
    category: str | None = None,
    _actor: CurrentActor = Depends(require_permissions("fleet.read")),
    session: AsyncSession = Depends(get_db_session),
) -> PaginatedResponse[VehicleResponse]:
    """List all fleet vehicles for staff."""
    return await VehicleService(session).list_vehicles(
        pagination=pagination, category=category, public_only=False
    )


@admin_router.post("", response_model=VehicleResponse, status_code=status.HTTP_201_CREATED)
async def create_vehicle(
    payload: VehicleCreateRequest,
    request: Request,
    actor: CurrentActor = Depends(require_permissions("fleet.write")),
    session: AsyncSession = Depends(get_db_session),
) -> VehicleResponse:
    """Create a fleet vehicle profile."""
    return await VehicleService(session).create_vehicle(
        payload,
        actor_id=actor.user_id,
        actor_role=actor.primary_role,
        correlation_id=getattr(request.state, "correlation_id", None),
    )


@admin_router.patch("/{vehicle_id}", response_model=VehicleResponse)
async def update_vehicle(
    vehicle_id: UUID,
    payload: VehicleUpdateRequest,
    request: Request,
    actor: CurrentActor = Depends(require_permissions("fleet.write")),
    session: AsyncSession = Depends(get_db_session),
) -> VehicleResponse:
    """Update a fleet vehicle."""
    return await VehicleService(session).update_vehicle(
        vehicle_id,
        payload,
        actor_id=actor.user_id,
        actor_role=actor.primary_role,
        correlation_id=getattr(request.state, "correlation_id", None),
    )


@admin_router.post(
    "/{vehicle_id}/images",
    response_model=VehicleImageResponse,
    status_code=status.HTTP_201_CREATED,
)
async def upload_vehicle_image(
    vehicle_id: UUID,
    file: UploadFile = File(...),
    is_primary: bool = Form(default=False),
    _actor: CurrentActor = Depends(require_permissions("fleet.write")),
    session: AsyncSession = Depends(get_db_session),
) -> VehicleImageResponse:
    """Upload a validated JPEG/PNG/WebP image for a vehicle."""
    data = await file.read()
    return await VehicleMediaService(session).upload_image(
        vehicle_id,
        data=data,
        filename=file.filename or "upload.jpg",
        is_primary=is_primary,
        storage=S3StorageClient(),
    )


@admin_router.get("/{vehicle_id}/calendar", response_model=list[ScheduleBlockResponse])
async def get_vehicle_calendar(
    vehicle_id: UUID,
    start_at: datetime,
    end_at: datetime,
    _actor: CurrentActor = Depends(require_permissions("fleet.read")),
    session: AsyncSession = Depends(get_db_session),
) -> list[ScheduleBlockResponse]:
    """Return active booking/maintenance schedule blocks for a vehicle."""
    return await VehicleMediaService(session).get_calendar(
        vehicle_id, start_at=start_at, end_at=end_at
    )
