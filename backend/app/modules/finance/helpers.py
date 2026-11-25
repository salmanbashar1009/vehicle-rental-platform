"""Shared helpers for booking financial authorization and summary calculations."""

from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ForbiddenError, NotFoundError
from app.modules.authentication.dependencies import CurrentActor
from app.modules.bookings.models import Booking, Quotation
from app.modules.customers.models import CustomerProfile
from app.modules.dispatch.models import Assignment
from app.modules.finance.models import Invoice, Payment, Refund
from app.modules.finance.schemas import BookingFinancialSummary
from app.modules.trips.models import Trip


async def load_booking_with_finance_acl(
    session: AsyncSession, booking_id: UUID, actor: CurrentActor, *, require_staff: bool = False
) -> Booking:
    """Verify booking existence and enforce either staff finance.read or customer ownership."""
    booking = (
        await session.execute(
            select(Booking).where(Booking.id == booking_id, Booking.deleted_at.is_(None))
        )
    ).scalar_one_or_none()
    if booking is None:
        raise NotFoundError("Booking not found.")
    if actor.has_permission("finance.read"):
        return booking
    if require_staff:
        raise ForbiddenError("Staff finance permission required.")

    profile = (
        await session.execute(
            select(CustomerProfile).where(CustomerProfile.user_id == actor.user_id)
        )
    ).scalar_one_or_none()
    if profile is None or booking.customer_id != profile.id:
        raise ForbiddenError("You do not have access to this booking's financial records.")
    return booking


async def compute_booking_summary(
    session: AsyncSession, booking: Booking
) -> BookingFinancialSummary:
    """Compute cash flow vs recognized booking value strictly using integer minor units."""
    accepted_quote = (
        await session.execute(
            select(Quotation)
            .where(Quotation.booking_id == booking.id, Quotation.status == "accepted")
            .order_by(Quotation.version.desc())
            .limit(1)
        )
    ).scalar_one_or_none()
    latest_quote = (
        accepted_quote
        or (
            await session.execute(
                select(Quotation)
                .where(Quotation.booking_id == booking.id)
                .order_by(Quotation.version.desc())
                .limit(1)
            )
        ).scalar_one_or_none()
    )

    quoted_minor = int(latest_quote.total_minor) if latest_quote else 0
    agreed_minor = int(accepted_quote.subtotal_minor) if accepted_quote else quoted_minor
    discount_minor = int(accepted_quote.discount_minor) if accepted_quote else 0
    currency = (
        accepted_quote.currency
        if accepted_quote
        else (latest_quote.currency if latest_quote else "USD")
    )

    trip_extra_raw = (
        await session.execute(
            select(func.coalesce(func.sum(Trip.extra_charges_minor), 0))
            .join(Assignment, Trip.assignment_id == Assignment.id)
            .where(Assignment.booking_id == booking.id, Assignment.is_current.is_(True))
        )
    ).scalar_one()
    extra_minor = int(trip_extra_raw or 0)

    paid_raw = (
        await session.execute(
            select(func.coalesce(func.sum(Payment.amount_minor), 0)).where(
                Payment.booking_id == booking.id,
                Payment.reconciliation_status == "reconciled",
            )
        )
    ).scalar_one()
    pending_raw = (
        await session.execute(
            select(func.coalesce(func.sum(Payment.amount_minor), 0)).where(
                Payment.booking_id == booking.id,
                Payment.reconciliation_status == "pending",
            )
        )
    ).scalar_one()
    refunded_raw = (
        await session.execute(
            select(func.coalesce(func.sum(Refund.amount_minor), 0)).where(
                Refund.booking_id == booking.id,
            )
        )
    ).scalar_one()

    paid_minor = int(paid_raw or 0)
    pending_minor = int(pending_raw or 0)
    refunded_minor = int(refunded_raw or 0)
    recognized = max(agreed_minor + extra_minor - discount_minor, 0)
    outstanding = max(recognized - paid_minor + refunded_minor, 0)

    return BookingFinancialSummary(
        booking_id=booking.id,
        booking_reference=booking.reference,
        currency=currency,
        quoted_minor=quoted_minor,
        agreed_minor=agreed_minor,
        extra_charges_minor=extra_minor,
        discount_minor=discount_minor,
        recognized_total_minor=recognized,
        paid_minor=paid_minor,
        pending_minor=pending_minor,
        refunded_minor=refunded_minor,
        outstanding_minor=outstanding,
    )


async def sync_invoice_statuses(session: AsyncSession, booking_id: UUID, paid_minor: int) -> None:
    """Update invoice payment status automatically as cash payments clear."""
    invoices = (
        (
            await session.execute(
                select(Invoice).where(Invoice.booking_id == booking_id, Invoice.status != "void")
            )
        )
        .scalars()
        .all()
    )
    for inv in invoices:
        if paid_minor >= inv.total_minor and inv.total_minor > 0:
            inv.status = "paid"
        elif paid_minor > 0:
            inv.status = "partially_paid"
