"""Booking lifecycle transitions: confirm, cancel, and reject."""

from uuid import UUID

from asyncpg.types import Range
from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import (
    ConflictError,
    ForbiddenError,
    NotFoundError,
    ValidationDomainError,
)
from app.modules.audit.service import AuditService
from app.modules.authentication.dependencies import CurrentActor
from app.modules.bookings.helpers import assert_customer_owns_booking, serialize_booking
from app.modules.bookings.models import BookingStatusHistory
from app.modules.bookings.repository import BookingRepository
from app.modules.bookings.schemas import BookingActionRequest, BookingResponse
from app.modules.vehicles.models import Vehicle, VehicleScheduleBlock


class BookingLifecycleService:
    """Handles transactional booking confirmation and cancellation/rejection."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._repo = BookingRepository(session)

    async def confirm_booking(
        self,
        booking_id: UUID,
        payload: BookingActionRequest,
        *,
        actor: CurrentActor,
        correlation_id: str | None,
    ) -> BookingResponse:
        """Confirm booking and atomically lock vehicle reservation if selected."""
        booking = await self._repo.get_by_id(booking_id, for_update=True)
        if booking is None:
            raise NotFoundError("Booking not found.")
        if booking.status not in ("requested", "under_review", "quote_accepted"):
            raise ValidationDomainError(f"Cannot confirm booking in status '{booking.status}'.")

        vehicle_id = payload.vehicle_id or booking.preferred_vehicle_id
        if vehicle_id is not None:
            vehicle = (
                await self._session.execute(
                    select(Vehicle)
                    .where(Vehicle.id == vehicle_id, Vehicle.deleted_at.is_(None))
                    .with_for_update()
                )
            ).scalar_one_or_none()
            if vehicle is None or vehicle.status in ("maintenance", "out_of_service"):
                raise ConflictError("Selected vehicle cannot be reserved.")
            self._session.add(
                VehicleScheduleBlock(
                    vehicle_id=vehicle.id,
                    block_type="booking",
                    source_id=booking.id,
                    time_range=Range(
                        booking.pickup_at, booking.expected_end_at, lower_inc=True, upper_inc=False
                    ),
                    is_active=True,
                )
            )
            booking.preferred_vehicle_id = vehicle.id

        prev = booking.status
        booking.status = "confirmed"
        self._session.add(
            BookingStatusHistory(
                booking_id=booking.id,
                from_status=prev,
                to_status="confirmed",
                changed_by=actor.user_id,
                reason=payload.reason or "Confirmed by staff",
            )
        )
        AuditService.record(
            self._session,
            actor_id=actor.user_id,
            actor_role=actor.primary_role,
            action="booking.confirmed",
            resource_type="booking",
            resource_id=str(booking.id),
            before_state={"status": prev},
            after_state={"status": "confirmed"},
            reason=payload.reason,
            correlation_id=correlation_id,
        )
        try:
            await self._session.commit()
        except IntegrityError as exc:
            await self._session.rollback()
            raise ConflictError("Vehicle already reserved for this time window.") from exc
        await self._session.refresh(booking)
        return serialize_booking(booking, include_internal=True)

    async def cancel_or_reject(
        self,
        booking_id: UUID,
        *,
        target_status: str,
        payload: BookingActionRequest,
        actor: CurrentActor,
        correlation_id: str | None,
    ) -> BookingResponse:
        """Cancel or reject a booking and release active schedule blocks."""
        booking = await self._repo.get_by_id(booking_id, for_update=True)
        if booking is None:
            raise NotFoundError("Booking not found.")
        is_staff = actor.has_permission("bookings.write")
        if not is_staff:
            if target_status != "cancelled":
                raise ForbiddenError("Insufficient permissions to reject booking.")
            await assert_customer_owns_booking(self._session, booking, actor)

        if booking.status in ("completed", "closed", "cancelled", "rejected"):
            raise ValidationDomainError(f"Booking is already '{booking.status}'.")

        prev = booking.status
        booking.status = target_status
        await self._session.execute(
            update(VehicleScheduleBlock)
            .where(
                VehicleScheduleBlock.source_id == booking.id,
                VehicleScheduleBlock.is_active.is_(True),
            )
            .values(is_active=False)
        )
        self._session.add(
            BookingStatusHistory(
                booking_id=booking.id,
                from_status=prev,
                to_status=target_status,
                changed_by=actor.user_id,
                reason=payload.reason,
            )
        )
        AuditService.record(
            self._session,
            actor_id=actor.user_id,
            actor_role=actor.primary_role,
            action=f"booking.{target_status}",
            resource_type="booking",
            resource_id=str(booking.id),
            before_state={"status": prev},
            after_state={"status": target_status},
            reason=payload.reason,
            correlation_id=correlation_id,
        )
        await self._session.commit()
        await self._session.refresh(booking)
        return serialize_booking(booking, include_internal=is_staff)
