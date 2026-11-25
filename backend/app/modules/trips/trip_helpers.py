"""Shared helpers for loading driver-owned trips and releasing schedule locks."""

from uuid import UUID

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ForbiddenError, NotFoundError
from app.modules.authentication.dependencies import CurrentActor
from app.modules.bookings.models import Booking
from app.modules.dispatch.models import Assignment
from app.modules.drivers.models import DriverProfile, DriverScheduleBlock
from app.modules.services.models import ServiceCategory
from app.modules.trips.models import Trip
from app.modules.vehicles.models import VehicleScheduleBlock


async def load_owned_trip(
    session: AsyncSession, trip_id: UUID, actor: CurrentActor, *, for_update: bool = False
) -> tuple[Trip, Assignment, DriverProfile, Booking, list[str]]:
    """Verify driver owns trip and return (trip, assignment, driver, booking, workflow_steps)."""
    driver = (
        await session.execute(
            select(DriverProfile).where(
                DriverProfile.user_id == actor.user_id, DriverProfile.deleted_at.is_(None)
            )
        )
    ).scalar_one_or_none()
    if driver is None:
        raise ForbiddenError("Driver profile not found.")

    stmt = select(Trip).where(Trip.id == trip_id)
    if for_update:
        stmt = stmt.with_for_update()
    trip = (await session.execute(stmt)).scalar_one_or_none()
    if trip is None:
        raise NotFoundError("Trip not found.")

    assignment = (
        await session.execute(select(Assignment).where(Assignment.id == trip.assignment_id))
    ).scalar_one()
    if assignment.driver_id != driver.id:
        raise ForbiddenError("You can only execute your own assigned trips.")

    booking = (
        await session.execute(select(Booking).where(Booking.id == assignment.booking_id))
    ).scalar_one()
    svc = (
        await session.execute(
            select(ServiceCategory).where(ServiceCategory.id == booking.service_category_id)
        )
    ).scalar_one()
    steps = svc.workflow.steps_json if svc.workflow else ["assigned", "service_completed"]
    return trip, assignment, driver, booking, steps


async def release_booking_locks(session: AsyncSession, booking_id: UUID) -> None:
    """Deactivate active vehicle and driver schedule locks upon completion or cancellation."""
    await session.execute(
        update(VehicleScheduleBlock)
        .where(
            VehicleScheduleBlock.source_id == booking_id,
            VehicleScheduleBlock.is_active.is_(True),
        )
        .values(is_active=False)
    )
    await session.execute(
        update(DriverScheduleBlock)
        .where(DriverScheduleBlock.source_id == booking_id, DriverScheduleBlock.is_active.is_(True))
        .values(is_active=False)
    )
