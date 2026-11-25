"""Quotation creation and customer acceptance/rejection service."""

from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import (
    ForbiddenError,
    NotFoundError,
    ValidationDomainError,
)
from app.modules.audit.service import AuditService
from app.modules.authentication.dependencies import CurrentActor
from app.modules.bookings.models import BookingStatusHistory, Quotation
from app.modules.bookings.repository import BookingRepository
from app.modules.bookings.schemas import QuotationCreateRequest, QuotationResponse
from app.modules.customers.models import CustomerProfile


class QuotationService:
    """Handles itemized quotation issuance and customer responses."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._repo = BookingRepository(session)

    async def create_quotation(
        self,
        booking_id: UUID,
        payload: QuotationCreateRequest,
        *,
        actor: CurrentActor,
        correlation_id: str | None,
    ) -> QuotationResponse:
        """Issue a versioned quotation and supersede prior open quotes."""
        booking = await self._repo.get_by_id(booking_id, for_update=True)
        if booking is None:
            raise NotFoundError("Booking not found.")
        if booking.status in ("completed", "closed", "cancelled", "rejected"):
            raise ValidationDomainError("Cannot issue quotation for closed/cancelled booking.")
        if payload.valid_until <= datetime.now(UTC):
            raise ValidationDomainError("valid_until must be in the future.")

        items = [
            {
                "label": i.label,
                "quantity": i.quantity,
                "unit_amount_minor": i.unit_amount_minor,
                "line_total_minor": i.quantity * i.unit_amount_minor,
            }
            for i in payload.items
        ]
        subtotal = sum(i.quantity * i.unit_amount_minor for i in payload.items)
        total = subtotal - payload.discount_minor + payload.tax_minor
        if total < 0:
            raise ValidationDomainError("Discount cannot exceed subtotal plus tax.")

        await self._session.execute(
            update(Quotation)
            .where(Quotation.booking_id == booking.id, Quotation.status == "sent")
            .values(status="superseded")
        )
        next_version = (max((q.version for q in booking.quotations), default=0)) + 1
        quote = Quotation(
            booking_id=booking.id,
            version=next_version,
            items_json=items,
            subtotal_minor=subtotal,
            discount_minor=payload.discount_minor,
            tax_minor=payload.tax_minor,
            total_minor=total,
            deposit_minor=payload.deposit_minor,
            currency=payload.currency.upper(),
            valid_until=payload.valid_until,
            terms=payload.terms,
            status="sent",
        )
        self._session.add(quote)
        prev = booking.status
        booking.status = "quoted"
        self._session.add(
            BookingStatusHistory(
                booking_id=booking.id,
                from_status=prev,
                to_status="quoted",
                changed_by=actor.user_id,
                reason=f"Quotation v{next_version} sent",
            )
        )
        AuditService.record(
            self._session,
            actor_id=actor.user_id,
            actor_role=actor.primary_role,
            action="quotation.sent",
            resource_type="quotation",
            resource_id=str(booking.id),
            after_state={"version": next_version, "total_minor": total, "currency": quote.currency},
            correlation_id=correlation_id,
        )
        await self._session.commit()
        await self._session.refresh(quote)
        return QuotationResponse.model_validate(quote)

    async def respond_to_quotation(
        self,
        quotation_id: UUID,
        *,
        accept: bool,
        actor: CurrentActor,
        correlation_id: str | None,
    ) -> QuotationResponse:
        """Customer accepts or rejects an active non-expired quotation."""
        quote = await self._repo.get_quotation(quotation_id)
        if quote is None:
            raise NotFoundError("Quotation not found.")

        booking = await self._repo.get_by_id(quote.booking_id, for_update=True)
        if booking is None:
            raise NotFoundError("Parent booking not found.")

        profile = (
            await self._session.execute(
                select(CustomerProfile).where(CustomerProfile.user_id == actor.user_id)
            )
        ).scalar_one_or_none()
        if profile is None or booking.customer_id != profile.id:
            raise ForbiddenError("You do not own this quotation.")

        if quote.status != "sent":
            raise ValidationDomainError(f"Quotation is already '{quote.status}'.")
        now = datetime.now(UTC)
        if accept and quote.valid_until <= now:
            quote.status = "expired"
            await self._session.commit()
            raise ValidationDomainError("Quotation has expired.", code="QUOTE_EXPIRED")

        quote.status = "accepted" if accept else "rejected"
        quote.responded_at = now
        prev = booking.status
        booking.status = "quote_accepted" if accept else "quote_rejected"
        self._session.add(
            BookingStatusHistory(
                booking_id=booking.id,
                from_status=prev,
                to_status=booking.status,
                changed_by=actor.user_id,
                reason=f"Customer {quote.status} quotation v{quote.version}",
            )
        )
        AuditService.record(
            self._session,
            actor_id=actor.user_id,
            actor_role=actor.primary_role,
            action=f"quotation.{quote.status}",
            resource_type="quotation",
            resource_id=str(quote.id),
            correlation_id=correlation_id,
        )
        await self._session.commit()
        await self._session.refresh(quote)
        return QuotationResponse.model_validate(quote)

    async def get_quotation(self, quotation_id: UUID, actor: CurrentActor) -> QuotationResponse:
        """Fetch single quotation enforcing staff bookings.read or owning customer."""
        quote = await self._repo.get_quotation(quotation_id)
        if quote is None:
            raise NotFoundError("Quotation not found.")
        if actor.has_permission("bookings.read"):
            return QuotationResponse.model_validate(quote)
        booking = await self._repo.get_by_id(quote.booking_id)
        profile = (
            await self._session.execute(
                select(CustomerProfile).where(CustomerProfile.user_id == actor.user_id)
            )
        ).scalar_one_or_none()
        if booking is None or profile is None or booking.customer_id != profile.id:
            raise ForbiddenError("You do not own this quotation.")
        return QuotationResponse.model_validate(quote)
