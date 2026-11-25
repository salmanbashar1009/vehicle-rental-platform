"""FastAPI router for driver assignments, trip execution, and incident reporting."""

from uuid import UUID

from fastapi import APIRouter, Depends, Header, Request, Response, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.idempotency import parse_idempotency_key
from app.database.session import get_db_session
from app.modules.authentication.dependencies import CurrentActor, require_permissions, require_roles
from app.modules.trips.assignment_read_service import DriverAssignmentReadService
from app.modules.trips.assignment_service import DriverAssignmentService
from app.modules.trips.completion_service import TripCompletionService
from app.modules.trips.execution_service import TripExecutionService
from app.modules.trips.models import IncidentReport
from app.modules.trips.schemas import (
    DeclineAssignmentRequest,
    DriverAssignmentDetailResponse,
    DriverAvailabilityUpdateRequest,
    IncidentCreateRequest,
    IncidentResponse,
    MilestoneTransitionRequest,
    TripCompleteRequest,
    TripResponse,
)

driver_router = APIRouter(prefix="/driver", tags=["Driver Operations"])
trips_router = APIRouter(prefix="/trips", tags=["Trips & Incidents"])
incidents_router = APIRouter(prefix="/incidents", tags=["Trips & Incidents"])


@driver_router.get("/assignments", response_model=list[DriverAssignmentDetailResponse])
async def list_driver_assignments(
    actor: CurrentActor = Depends(require_roles("driver")),
    session: AsyncSession = Depends(get_db_session),
) -> list[DriverAssignmentDetailResponse]:
    """List assignments owned strictly by current authenticated driver."""
    return await DriverAssignmentReadService(session).list_my_assignments(actor)


@driver_router.post("/assignments/{assignment_id}/ack", response_model=TripResponse)
async def acknowledge_assignment(
    assignment_id: UUID,
    request: Request,
    actor: CurrentActor = Depends(require_roles("driver")),
    session: AsyncSession = Depends(get_db_session),
) -> TripResponse:
    """Driver acknowledges assignment and initializes trip execution."""
    return await DriverAssignmentService(session).acknowledge(
        assignment_id,
        actor=actor,
        correlation_id=getattr(request.state, "correlation_id", None),
    )


@driver_router.post("/assignments/{assignment_id}/decline", status_code=status.HTTP_204_NO_CONTENT)
async def decline_assignment(
    assignment_id: UUID,
    payload: DeclineAssignmentRequest,
    request: Request,
    actor: CurrentActor = Depends(require_roles("driver")),
    session: AsyncSession = Depends(get_db_session),
) -> Response:
    """Driver reports inability to attend; triggers urgent dispatcher notification."""
    await DriverAssignmentService(session).decline(
        assignment_id,
        reason=payload.reason,
        actor=actor,
        correlation_id=getattr(request.state, "correlation_id", None),
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@driver_router.patch("/availability")
async def update_driver_availability(
    payload: DriverAvailabilityUpdateRequest,
    actor: CurrentActor = Depends(require_roles("driver")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, str]:
    """Toggle driver duty availability when no active trip is running."""
    updated = await DriverAssignmentService(session).update_my_availability(
        status=payload.availability_status, actor=actor
    )
    return {"availability_status": updated}


@trips_router.post("/{trip_id}/milestones", response_model=TripResponse)
async def advance_trip_milestone(
    trip_id: UUID,
    payload: MilestoneTransitionRequest,
    request: Request,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    actor: CurrentActor = Depends(require_roles("driver")),
    session: AsyncSession = Depends(get_db_session),
) -> TripResponse:
    """Advance trip milestone idempotently along service workflow."""
    valid_key = parse_idempotency_key(idempotency_key)
    return await TripExecutionService(session).transition_milestone(
        trip_id,
        payload,
        actor=actor,
        idempotency_key=valid_key,
        correlation_id=getattr(request.state, "correlation_id", None),
    )


@trips_router.post("/{trip_id}/complete", response_model=TripResponse)
async def complete_trip(
    trip_id: UUID,
    payload: TripCompleteRequest,
    request: Request,
    actor: CurrentActor = Depends(require_roles("driver")),
    session: AsyncSession = Depends(get_db_session),
) -> TripResponse:
    """Submit final odometer, waiting time, extra charges, and complete trip."""
    return await TripCompletionService(session).complete_trip(
        trip_id,
        payload,
        actor=actor,
        correlation_id=getattr(request.state, "correlation_id", None),
    )


@trips_router.post(
    "/{trip_id}/incidents",
    response_model=IncidentResponse,
    status_code=status.HTTP_201_CREATED,
)
async def report_trip_incident(
    trip_id: UUID,
    payload: IncidentCreateRequest,
    request: Request,
    actor: CurrentActor = Depends(require_roles("driver")),
    session: AsyncSession = Depends(get_db_session),
) -> IncidentResponse:
    """Report breakdown, accident, medical emergency, or dispute."""
    return await TripCompletionService(session).report_incident(
        trip_id,
        payload,
        actor=actor,
        correlation_id=getattr(request.state, "correlation_id", None),
    )


@incidents_router.get("", response_model=list[IncidentResponse])
async def list_incidents(
    _actor: CurrentActor = Depends(require_permissions("trips.read")),
    session: AsyncSession = Depends(get_db_session),
) -> list[IncidentResponse]:
    """List driver-reported operational incidents for staff."""
    rows = (
        (await session.execute(select(IncidentReport).order_by(IncidentReport.created_at.desc())))
        .scalars()
        .all()
    )
    return [IncidentResponse.model_validate(r) for r in rows]
