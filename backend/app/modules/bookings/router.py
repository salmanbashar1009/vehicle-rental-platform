"""FastAPI routers for bookings and quotations."""

from uuid import UUID

from fastapi import APIRouter, Depends, Header, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.idempotency import parse_idempotency_key
from app.core.pagination import PaginatedResponse, PaginationParams
from app.database.session import get_db_session
from app.modules.authentication.dependencies import (
    CurrentActor,
    get_current_actor,
    get_optional_actor,
    require_permissions,
)
from app.modules.bookings.lifecycle_service import BookingLifecycleService
from app.modules.bookings.quotation_service import QuotationService
from app.modules.bookings.reschedule_service import BookingRescheduleService
from app.modules.bookings.schemas import (
    BookingActionRequest,
    BookingCreateRequest,
    BookingRescheduleRequest,
    BookingResponse,
    QuotationCreateRequest,
    QuotationResponse,
)
from app.modules.bookings.service import BookingService

bookings_router = APIRouter(prefix="/bookings", tags=["Bookings"])


@bookings_router.post("", response_model=BookingResponse, status_code=status.HTTP_201_CREATED)
async def create_booking(
    payload: BookingCreateRequest,
    request: Request,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    actor: CurrentActor | None = Depends(get_optional_actor),
    session: AsyncSession = Depends(get_db_session),
) -> BookingResponse:
    """Create a booking request idempotently (authenticated customer or guest)."""
    valid_key = parse_idempotency_key(idempotency_key)
    return await BookingService(session).create_booking(
        payload,
        actor=actor,
        idempotency_key=valid_key,
        correlation_id=getattr(request.state, "correlation_id", None),
    )


@bookings_router.get("", response_model=PaginatedResponse[BookingResponse])
async def list_bookings(
    pagination: PaginationParams = Depends(),
    status_filter: str | None = None,
    search: str | None = None,
    actor: CurrentActor = Depends(get_current_actor),
    session: AsyncSession = Depends(get_db_session),
) -> PaginatedResponse[BookingResponse]:
    """List bookings (staff sees all; customers see own only)."""
    return await BookingService(session).list_bookings(
        actor=actor, pagination=pagination, status=status_filter, search=search
    )


@bookings_router.get("/{booking_id}", response_model=BookingResponse)
async def get_booking(
    booking_id: UUID,
    actor: CurrentActor = Depends(get_current_actor),
    session: AsyncSession = Depends(get_db_session),
) -> BookingResponse:
    """Get single booking detail with ownership check."""
    return await BookingService(session).get_booking(booking_id, actor=actor)


@bookings_router.post("/{booking_id}/confirm", response_model=BookingResponse)
async def confirm_booking(
    booking_id: UUID,
    payload: BookingActionRequest,
    request: Request,
    actor: CurrentActor = Depends(require_permissions("bookings.write")),
    session: AsyncSession = Depends(get_db_session),
) -> BookingResponse:
    """Confirm booking and lock optional vehicle reservation."""
    return await BookingLifecycleService(session).confirm_booking(
        booking_id,
        payload,
        actor=actor,
        correlation_id=getattr(request.state, "correlation_id", None),
    )


@bookings_router.post("/{booking_id}/reject", response_model=BookingResponse)
async def reject_booking(
    booking_id: UUID,
    payload: BookingActionRequest,
    request: Request,
    actor: CurrentActor = Depends(require_permissions("bookings.write")),
    session: AsyncSession = Depends(get_db_session),
) -> BookingResponse:
    """Reject a booking request."""
    return await BookingLifecycleService(session).cancel_or_reject(
        booking_id,
        target_status="rejected",
        payload=payload,
        actor=actor,
        correlation_id=getattr(request.state, "correlation_id", None),
    )


@bookings_router.post("/{booking_id}/cancel", response_model=BookingResponse)
async def cancel_booking(
    booking_id: UUID,
    payload: BookingActionRequest,
    request: Request,
    actor: CurrentActor = Depends(get_current_actor),
    session: AsyncSession = Depends(get_db_session),
) -> BookingResponse:
    """Cancel a booking (staff or owning customer)."""
    return await BookingLifecycleService(session).cancel_or_reject(
        booking_id,
        target_status="cancelled",
        payload=payload,
        actor=actor,
        correlation_id=getattr(request.state, "correlation_id", None),
    )


@bookings_router.post("/{booking_id}/reschedule", response_model=BookingResponse)
async def reschedule_booking(
    booking_id: UUID,
    payload: BookingRescheduleRequest,
    request: Request,
    actor: CurrentActor = Depends(require_permissions("bookings.write")),
    session: AsyncSession = Depends(get_db_session),
) -> BookingResponse:
    """Reschedule booking dates while verifying vehicle availability."""
    return await BookingRescheduleService(session).reschedule_booking(
        booking_id,
        payload,
        actor=actor,
        correlation_id=getattr(request.state, "correlation_id", None),
    )


@bookings_router.post(
    "/{booking_id}/quotations",
    response_model=QuotationResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_quotation(
    booking_id: UUID,
    payload: QuotationCreateRequest,
    request: Request,
    actor: CurrentActor = Depends(require_permissions("bookings.write")),
    session: AsyncSession = Depends(get_db_session),
) -> QuotationResponse:
    """Create and send an itemized quotation for a booking."""
    return await QuotationService(session).create_quotation(
        booking_id,
        payload,
        actor=actor,
        correlation_id=getattr(request.state, "correlation_id", None),
    )
