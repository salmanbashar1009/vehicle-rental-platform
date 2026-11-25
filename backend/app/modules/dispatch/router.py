"""FastAPI router for dispatch eligibility and assignments."""

from uuid import UUID

from fastapi import APIRouter, Depends, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.session import get_db_session
from app.modules.authentication.dependencies import CurrentActor, require_permissions
from app.modules.dispatch.eligibility_service import DispatchEligibilityService
from app.modules.dispatch.schemas import (
    AssignmentResponse,
    DispatchAssignRequest,
    EligibleResourcesResponse,
)
from app.modules.dispatch.service import DispatchService

router = APIRouter(prefix="/dispatch", tags=["Dispatch"])


@router.get("/eligible-resources", response_model=EligibleResourcesResponse)
async def get_eligible_resources(
    booking_id: UUID,
    _actor: CurrentActor = Depends(require_permissions("dispatch.read")),
    session: AsyncSession = Depends(get_db_session),
) -> EligibleResourcesResponse:
    """List eligible vehicles and drivers with conflict indicators for a booking."""
    return await DispatchEligibilityService(session).get_eligible_resources(booking_id)


@router.post("/assign", response_model=AssignmentResponse, status_code=status.HTTP_201_CREATED)
async def assign_resources(
    payload: DispatchAssignRequest,
    request: Request,
    actor: CurrentActor = Depends(require_permissions("dispatch.write")),
    session: AsyncSession = Depends(get_db_session),
) -> AssignmentResponse:
    """Assign a vehicle and driver to a confirmed booking atomically."""
    return await DispatchService(session).assign(
        payload,
        is_reassignment=False,
        actor=actor,
        correlation_id=getattr(request.state, "correlation_id", None),
    )


@router.post("/reassign", response_model=AssignmentResponse)
async def reassign_resources(
    payload: DispatchAssignRequest,
    request: Request,
    actor: CurrentActor = Depends(require_permissions("dispatch.write")),
    session: AsyncSession = Depends(get_db_session),
) -> AssignmentResponse:
    """Reassign a vehicle and/or driver while recording assignment history."""
    return await DispatchService(session).assign(
        payload,
        is_reassignment=True,
        actor=actor,
        correlation_id=getattr(request.state, "correlation_id", None),
    )
