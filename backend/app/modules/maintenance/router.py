"""FastAPI router for fleet maintenance schedules and document/licence expiry scans."""

from uuid import UUID

from fastapi import APIRouter, Depends, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.session import get_db_session
from app.modules.authentication.dependencies import CurrentActor, require_permissions
from app.modules.maintenance.expiry_service import ExpiryReminderService
from app.modules.maintenance.schemas import (
    ExpiryScanResponse,
    MaintenanceCreateRequest,
    MaintenanceResponse,
    MaintenanceStatusUpdateRequest,
)
from app.modules.maintenance.service import MaintenanceService

router = APIRouter(prefix="/maintenance", tags=["Fleet Maintenance"])


@router.post("", response_model=MaintenanceResponse, status_code=status.HTTP_201_CREATED)
async def schedule_maintenance(
    payload: MaintenanceCreateRequest,
    request: Request,
    actor: CurrentActor = Depends(require_permissions("fleet.write")),
    session: AsyncSession = Depends(get_db_session),
) -> MaintenanceResponse:
    """Schedule vehicle maintenance and lock vehicle availability (`409` on overlap)."""
    return await MaintenanceService(session).schedule_maintenance(
        payload, actor=actor, correlation_id=getattr(request.state, "correlation_id", None)
    )


@router.get("", response_model=list[MaintenanceResponse])
async def list_maintenance(
    vehicle_id: UUID | None = None,
    _actor: CurrentActor = Depends(require_permissions("fleet.read")),
    session: AsyncSession = Depends(get_db_session),
) -> list[MaintenanceResponse]:
    """List scheduled and historical vehicle maintenance records."""
    return await MaintenanceService(session).list_maintenance(vehicle_id=vehicle_id)


@router.patch("/{maint_id}", response_model=MaintenanceResponse)
async def update_maintenance_status(
    maint_id: UUID,
    payload: MaintenanceStatusUpdateRequest,
    request: Request,
    actor: CurrentActor = Depends(require_permissions("fleet.write")),
    session: AsyncSession = Depends(get_db_session),
) -> MaintenanceResponse:
    """Update maintenance status and release calendar block upon completion/cancellation."""
    return await MaintenanceService(session).update_status(
        maint_id,
        payload,
        actor=actor,
        correlation_id=getattr(request.state, "correlation_id", None),
    )


@router.post("/expiry-scan", response_model=ExpiryScanResponse)
async def run_expiry_scan(
    _actor: CurrentActor = Depends(require_permissions("fleet.write")),
    session: AsyncSession = Depends(get_db_session),
) -> ExpiryScanResponse:
    """Trigger document & driver licence expiry notification scan."""
    return await ExpiryReminderService(session).scan_expiry_reminders()
