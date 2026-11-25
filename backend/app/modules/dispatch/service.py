"""Transaction-safe dispatch service with PostgreSQL exclusion conflict protection."""

from datetime import UTC, datetime

from asyncpg.types import Range
from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, NotFoundError, ValidationDomainError
from app.modules.audit.service import AuditService
from app.modules.authentication.dependencies import CurrentActor
from app.modules.bookings.models import Booking, BookingStatusHistory
from app.modules.dispatch.models import Assignment, AssignmentHistory
from app.modules.dispatch.schemas import AssignmentResponse, DispatchAssignRequest
from app.modules.drivers.models import DriverProfile, DriverScheduleBlock
from app.modules.vehicles.models import Vehicle, VehicleScheduleBlock


class DispatchService:
    """Manages atomic vehicle+driver allocation and reassignment."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def assign(
        self,
        payload: DispatchAssignRequest,
        *,
        is_reassignment: bool,
        actor: CurrentActor,
        correlation_id: str | None,
    ) -> AssignmentResponse:
        """Atomically assign or reassign vehicle and driver under exclusion constraints."""
        booking = (
            await self._session.execute(
                select(Booking)
                .where(Booking.id == payload.booking_id, Booking.deleted_at.is_(None))
                .with_for_update()
            )
        ).scalar_one_or_none()
        if booking is None:
            raise NotFoundError("Booking not found.")
        if booking.status not in ("confirmed", "assigned"):
            raise ValidationDomainError("Booking must be confirmed before dispatch.")

        vehicle = (
            await self._session.execute(
                select(Vehicle)
                .where(Vehicle.id == payload.vehicle_id, Vehicle.deleted_at.is_(None))
                .with_for_update()
            )
        ).scalar_one_or_none()
        if vehicle is None or vehicle.status in ("maintenance", "out_of_service"):
            raise ConflictError("Vehicle is unavailable or under maintenance.")

        driver = (
            await self._session.execute(
                select(DriverProfile)
                .where(DriverProfile.id == payload.driver_id, DriverProfile.deleted_at.is_(None))
                .with_for_update()
            )
        ).scalar_one_or_none()
        if driver is None or driver.employment_status != "active":
            raise ConflictError("Driver is unavailable.")
        if driver.licence_expiry <= datetime.now(UTC).date():
            raise ConflictError("Driver licence is expired.")
        if driver.availability_status in ("off_duty", "unavailable"):
            raise ConflictError(f"Driver is currently {driver.availability_status}.")

        await self._release_existing_locks(booking)
        window = Range(booking.pickup_at, booking.expected_end_at, lower_inc=True, upper_inc=False)
        self._session.add(
            VehicleScheduleBlock(
                vehicle_id=vehicle.id,
                block_type="booking",
                source_id=booking.id,
                time_range=window,
                is_active=True,
            )
        )
        self._session.add(
            DriverScheduleBlock(
                driver_id=driver.id,
                block_type="assignment",
                source_id=booking.id,
                time_range=window,
                is_active=True,
            )
        )

        assignment = Assignment(
            booking_id=booking.id,
            vehicle_id=vehicle.id,
            driver_id=driver.id,
            status="pending_ack",
            assigned_by=actor.user_id,
            is_current=True,
        )
        self._session.add(assignment)
        try:
            await self._session.flush()
        except IntegrityError as exc:
            await self._session.rollback()
            raise ConflictError(
                "Vehicle or driver has a conflicting schedule in this time window."
            ) from exc

        prev_status = booking.status
        booking.status = "assigned"
        if prev_status != "assigned":
            self._session.add(
                BookingStatusHistory(
                    booking_id=booking.id,
                    from_status=prev_status,
                    to_status="assigned",
                    changed_by=actor.user_id,
                    reason=payload.reason or "Vehicle and driver dispatched",
                )
            )
        action_name = "reassigned" if is_reassignment else "assigned"
        self._session.add(
            AssignmentHistory(
                assignment_id=assignment.id,
                booking_id=booking.id,
                vehicle_id=vehicle.id,
                driver_id=driver.id,
                action=action_name,
                actor_id=actor.user_id,
                reason=payload.reason,
            )
        )
        AuditService.record(
            self._session,
            actor_id=actor.user_id,
            actor_role=actor.primary_role,
            action=f"dispatch.{action_name}",
            resource_type="assignment",
            resource_id=str(assignment.id),
            after_state={
                "booking_id": str(booking.id),
                "vehicle_id": str(vehicle.id),
                "driver_id": str(driver.id),
            },
            reason=payload.reason,
            correlation_id=correlation_id,
        )
        try:
            await self._session.commit()
        except IntegrityError as exc:
            await self._session.rollback()
            raise ConflictError(
                "Vehicle or driver has a conflicting schedule in this time window."
            ) from exc
        await self._session.refresh(assignment)
        return AssignmentResponse.model_validate(assignment)

    async def _release_existing_locks(self, booking: Booking) -> None:
        await self._session.execute(
            update(VehicleScheduleBlock)
            .where(
                VehicleScheduleBlock.source_id == booking.id,
                VehicleScheduleBlock.is_active.is_(True),
            )
            .values(is_active=False)
        )
        await self._session.execute(
            update(DriverScheduleBlock)
            .where(
                DriverScheduleBlock.source_id == booking.id,
                DriverScheduleBlock.is_active.is_(True),
            )
            .values(is_active=False)
        )
        await self._session.execute(
            update(Assignment)
            .where(Assignment.booking_id == booking.id, Assignment.is_current.is_(True))
            .values(is_current=False, status="reassigned")
        )
