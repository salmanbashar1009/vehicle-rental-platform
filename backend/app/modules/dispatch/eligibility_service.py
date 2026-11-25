"""Eligible vehicle and driver lookup service for dispatchers."""

from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NotFoundError
from app.modules.bookings.models import Booking
from app.modules.dispatch.schemas import (
    EligibleDriverItem,
    EligibleResourcesResponse,
    EligibleVehicleItem,
)
from app.modules.drivers.models import DriverProfile
from app.modules.drivers.service import DriverService
from app.modules.vehicles.models import Vehicle
from app.modules.vehicles.repository import VehicleRepository


class DispatchEligibilityService:
    """Evaluates vehicle and driver eligibility for a booking window."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_eligible_resources(self, booking_id: UUID) -> EligibleResourcesResponse:
        """Return vehicles and drivers annotated with eligibility and conflicts."""
        booking = (
            await self._session.execute(
                select(Booking).where(Booking.id == booking_id, Booking.deleted_at.is_(None))
            )
        ).scalar_one_or_none()
        if booking is None:
            raise NotFoundError("Booking not found.")

        busy_vehicles = await VehicleRepository(self._session).overlapping_vehicle_ids(
            start_at=booking.pickup_at,
            end_at=booking.expected_end_at,
            exclude_source_id=booking.id,
        )
        busy_drivers = await DriverService(self._session).overlapping_driver_ids(
            start_at=booking.pickup_at,
            end_at=booking.expected_end_at,
            exclude_source_id=booking.id,
        )

        vehicles = (
            (await self._session.execute(select(Vehicle).where(Vehicle.deleted_at.is_(None))))
            .scalars()
            .all()
        )
        drivers = (
            (
                await self._session.execute(
                    select(DriverProfile).where(DriverProfile.deleted_at.is_(None))
                )
            )
            .scalars()
            .all()
        )

        veh_items: list[EligibleVehicleItem] = []
        for v in vehicles:
            reason: str | None = None
            if v.status in ("maintenance", "out_of_service"):
                reason = f"vehicle_{v.status}"
            elif v.id in busy_vehicles:
                reason = "schedule_overlap"
            elif v.seat_capacity < booking.passenger_count:
                reason = "insufficient_capacity"
            veh_items.append(
                EligibleVehicleItem(
                    id=v.id,
                    plate_number=v.plate_number,
                    name=v.name,
                    category=v.category,
                    seat_capacity=v.seat_capacity,
                    status=v.status,
                    is_eligible=reason is None,
                    conflict_reason=reason,
                )
            )

        today = datetime.now(UTC).date()
        drv_items: list[EligibleDriverItem] = []
        for d in drivers:
            reason = None
            if d.employment_status != "active":
                reason = "inactive_employment"
            elif d.licence_expiry <= today:
                reason = "licence_expired"
            elif d.availability_status in ("off_duty", "unavailable"):
                reason = f"driver_{d.availability_status}"
            elif d.id in busy_drivers:
                reason = "schedule_overlap"
            drv_items.append(
                EligibleDriverItem(
                    id=d.id,
                    full_name=d.user.full_name,
                    phone=d.user.phone,
                    licence_number=d.licence_number,
                    licence_expiry=d.licence_expiry,
                    availability_status=d.availability_status,
                    is_eligible=reason is None,
                    conflict_reason=reason,
                )
            )

        return EligibleResourcesResponse(
            booking_id=booking.id,
            pickup_at=booking.pickup_at,
            expected_end_at=booking.expected_end_at,
            vehicles=veh_items,
            drivers=drv_items,
        )
