"""Booking rescheduling service preserving vehicle availability invariants."""

from uuid import UUID

from asyncpg.types import Range
from sqlalchemy import update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, NotFoundError, ValidationDomainError
from app.modules.audit.service import AuditService
from app.modules.authentication.dependencies import CurrentActor
from app.modules.bookings.helpers import serialize_booking
from app.modules.bookings.repository import BookingRepository
from app.modules.bookings.schemas import BookingRescheduleRequest, BookingResponse
from app.modules.vehicles.models import VehicleScheduleBlock


class BookingRescheduleService:
    """Reschedules booking windows atomically under schedule exclusion constraints."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._repo = BookingRepository(session)

    async def reschedule_booking(
        self,
        booking_id: UUID,
        payload: BookingRescheduleRequest,
        *,
        actor: CurrentActor,
        correlation_id: str | None,
    ) -> BookingResponse:
        """Reschedule booking dates updating any active vehicle block atomically."""
        if payload.expected_end_at <= payload.pickup_at:
            raise ValidationDomainError("expected_end_at must be after pickup_at.")
        booking = await self._repo.get_by_id(booking_id, for_update=True)
        if booking is None:
            raise NotFoundError("Booking not found.")
        if booking.status in ("in_progress", "completed", "closed", "cancelled", "rejected"):
            raise ValidationDomainError("Cannot reschedule booking in its current status.")

        before = {
            "pickup_at": booking.pickup_at.isoformat(),
            "expected_end_at": booking.expected_end_at.isoformat(),
        }
        booking.pickup_at = payload.pickup_at
        booking.expected_end_at = payload.expected_end_at
        new_range = Range(
            payload.pickup_at, payload.expected_end_at, lower_inc=True, upper_inc=False
        )
        await self._session.execute(
            update(VehicleScheduleBlock)
            .where(
                VehicleScheduleBlock.source_id == booking.id,
                VehicleScheduleBlock.is_active.is_(True),
            )
            .values(time_range=new_range)
        )
        AuditService.record(
            self._session,
            actor_id=actor.user_id,
            actor_role=actor.primary_role,
            action="booking.rescheduled",
            resource_type="booking",
            resource_id=str(booking.id),
            before_state=before,
            after_state={
                "pickup_at": payload.pickup_at.isoformat(),
                "expected_end_at": payload.expected_end_at.isoformat(),
            },
            reason=payload.reason,
            correlation_id=correlation_id,
        )
        try:
            await self._session.commit()
        except IntegrityError as exc:
            await self._session.rollback()
            raise ConflictError(
                "Rescheduled window conflicts with an existing reservation."
            ) from exc
        await self._session.refresh(booking)
        return serialize_booking(booking, include_internal=True)
