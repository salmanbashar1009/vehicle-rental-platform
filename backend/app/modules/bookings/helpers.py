"""Shared booking serialization and customer ownership helpers."""

import secrets
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ForbiddenError
from app.modules.authentication.dependencies import CurrentActor
from app.modules.bookings.models import Booking
from app.modules.bookings.schemas import BookingResponse
from app.modules.customers.models import CustomerProfile


def generate_booking_ref() -> str:
    """Generate human-readable unique booking reference."""
    today = datetime.now(UTC).strftime("%Y%m%d")
    return f"VF-{today}-{secrets.token_hex(3).upper()}"


def serialize_booking(
    booking: Booking, *, include_internal: bool, claim_token: str | None = None
) -> BookingResponse:
    """Serialize booking hiding staff-only internal_notes from customers."""
    dto = BookingResponse.model_validate(booking)
    if not include_internal:
        dto.internal_notes = None
    dto.guest_claim_token = claim_token
    return dto


async def assert_customer_owns_booking(
    session: AsyncSession, booking: Booking, actor: CurrentActor
) -> None:
    """Raise ForbiddenError if actor is not the booking's customer owner."""
    profile = (
        await session.execute(
            select(CustomerProfile).where(CustomerProfile.user_id == actor.user_id)
        )
    ).scalar_one_or_none()
    if profile is None or booking.customer_id != profile.id:
        raise ForbiddenError("You do not have access to this booking.")
