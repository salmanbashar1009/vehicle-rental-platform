"""FastAPI router for quotation viewing, acceptance, and rejection."""

from uuid import UUID

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.session import get_db_session
from app.modules.authentication.dependencies import CurrentActor, get_current_actor, require_roles
from app.modules.bookings.quotation_service import QuotationService
from app.modules.bookings.schemas import QuotationResponse

quotations_router = APIRouter(prefix="/quotations", tags=["Bookings"])


@quotations_router.get("/{quotation_id}", response_model=QuotationResponse)
async def get_quotation(
    quotation_id: UUID,
    actor: CurrentActor = Depends(get_current_actor),
    session: AsyncSession = Depends(get_db_session),
) -> QuotationResponse:
    """View quotation detail (staff or booking owner)."""
    return await QuotationService(session).get_quotation(quotation_id, actor=actor)


@quotations_router.post("/{quotation_id}/accept", response_model=QuotationResponse)
async def accept_quotation(
    quotation_id: UUID,
    request: Request,
    actor: CurrentActor = Depends(require_roles("customer")),
    session: AsyncSession = Depends(get_db_session),
) -> QuotationResponse:
    """Customer accepts a quotation."""
    return await QuotationService(session).respond_to_quotation(
        quotation_id,
        accept=True,
        actor=actor,
        correlation_id=getattr(request.state, "correlation_id", None),
    )


@quotations_router.post("/{quotation_id}/reject", response_model=QuotationResponse)
async def reject_quotation(
    quotation_id: UUID,
    request: Request,
    actor: CurrentActor = Depends(require_roles("customer")),
    session: AsyncSession = Depends(get_db_session),
) -> QuotationResponse:
    """Customer rejects a quotation."""
    return await QuotationService(session).respond_to_quotation(
        quotation_id,
        accept=False,
        actor=actor,
        correlation_id=getattr(request.state, "correlation_id", None),
    )
