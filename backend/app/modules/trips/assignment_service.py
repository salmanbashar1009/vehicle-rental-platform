"""Driver-facing assignment acknowledgement, decline, and duty availability."""

from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError, ValidationDomainError
from app.modules.audit.service import AuditService
from app.modules.authentication.dependencies import CurrentActor
from app.modules.bookings.models import Booking, BookingStatusHistory
from app.modules.dispatch.models import Assignment, AssignmentHistory
from app.modules.drivers.models import DriverScheduleBlock
from app.modules.notifications.service import NotificationService
from app.modules.trips.assignment_read_service import resolve_driver_profile
from app.modules.trips.models import Trip
from app.modules.trips.schemas import TripResponse
from app.modules.vehicles.models import VehicleScheduleBlock


class DriverAssignmentService:
    """Handles driver-owned assignment ack, decline, and duty status."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def acknowledge(
        self, assignment_id: UUID, *, actor: CurrentActor, correlation_id: str | None
    ) -> TripResponse:
        """Driver acknowledges assignment and initializes Trip record."""
        driver = await resolve_driver_profile(self._session, actor)
        assignment = (
            await self._session.execute(
                select(Assignment).where(Assignment.id == assignment_id).with_for_update()
            )
        ).scalar_one_or_none()
        if assignment is None:
            raise NotFoundError("Assignment not found.")
        if assignment.driver_id != driver.id:
            raise ForbiddenError("You can only acknowledge your own assignments.")
        if assignment.status not in ("pending_ack", "acknowledged"):
            raise ValidationDomainError(f"Cannot acknowledge assignment in '{assignment.status}'.")

        assignment.status = "acknowledged"
        assignment.acknowledged_at = datetime.now(UTC)

        trip = (
            await self._session.execute(select(Trip).where(Trip.assignment_id == assignment.id))
        ).scalar_one_or_none()
        if trip is None:
            trip = Trip(assignment_id=assignment.id, status="assigned")
            self._session.add(trip)

        AuditService.record(
            self._session,
            actor_id=actor.user_id,
            actor_role="driver",
            action="assignment.acknowledged",
            resource_type="assignment",
            resource_id=str(assignment.id),
            correlation_id=correlation_id,
        )
        await self._session.commit()
        await self._session.refresh(trip)
        return TripResponse.model_validate(trip)

    async def decline(
        self,
        assignment_id: UUID,
        *,
        reason: str,
        actor: CurrentActor,
        correlation_id: str | None,
    ) -> None:
        """Driver reports inability to attend; releases schedule blocks and alerts dispatcher."""
        driver = await resolve_driver_profile(self._session, actor)
        assignment = (
            await self._session.execute(
                select(Assignment).where(Assignment.id == assignment_id).with_for_update()
            )
        ).scalar_one_or_none()
        if assignment is None:
            raise NotFoundError("Assignment not found.")
        if assignment.driver_id != driver.id:
            raise ForbiddenError("You can only decline your own assignments.")
        if assignment.status not in ("pending_ack", "acknowledged"):
            raise ValidationDomainError("Cannot decline an active or completed assignment.")

        assignment.status = "declined"
        assignment.decline_reason = reason
        assignment.is_current = False

        booking = (
            await self._session.execute(
                select(Booking).where(Booking.id == assignment.booking_id).with_for_update()
            )
        ).scalar_one()
        booking.status = "confirmed"
        self._session.add(
            BookingStatusHistory(
                booking_id=booking.id,
                from_status="assigned",
                to_status="confirmed",
                changed_by=actor.user_id,
                reason=f"Driver declined assignment: {reason}",
            )
        )
        await self._session.execute(
            update(DriverScheduleBlock)
            .where(
                DriverScheduleBlock.source_id == booking.id, DriverScheduleBlock.is_active.is_(True)
            )
            .values(is_active=False)
        )
        await self._session.execute(
            update(VehicleScheduleBlock)
            .where(
                VehicleScheduleBlock.source_id == booking.id,
                VehicleScheduleBlock.is_active.is_(True),
            )
            .values(is_active=False)
        )
        self._session.add(
            AssignmentHistory(
                assignment_id=assignment.id,
                booking_id=booking.id,
                vehicle_id=assignment.vehicle_id,
                driver_id=driver.id,
                action="declined",
                actor_id=actor.user_id,
                reason=reason,
            )
        )
        await NotificationService.enqueue(
            self._session,
            user_id=assignment.assigned_by,
            event_type="assignment.declined",
            title=f"Driver declined {booking.reference}",
            body=reason,
            dedup_key=f"declined:{assignment.id}",
            priority="high",
            resource_type="booking",
            resource_id=str(booking.id),
        )
        AuditService.record(
            self._session,
            actor_id=actor.user_id,
            actor_role="driver",
            action="assignment.declined",
            resource_type="assignment",
            resource_id=str(assignment.id),
            reason=reason,
            correlation_id=correlation_id,
        )
        await self._session.commit()

    async def update_my_availability(self, *, status: str, actor: CurrentActor) -> str:
        """Allow driver to toggle available/on_break/off_duty unless an active trip runs."""
        driver = await resolve_driver_profile(self._session, actor)
        active = (
            await self._session.execute(
                select(Assignment).where(
                    Assignment.driver_id == driver.id,
                    Assignment.is_current.is_(True),
                    Assignment.status == "active",
                )
            )
        ).scalar_one_or_none()
        if active is not None:
            raise ConflictError("Cannot go off duty while an active trip is in progress.")
        driver.availability_status = status
        await self._session.commit()
        return driver.availability_status
