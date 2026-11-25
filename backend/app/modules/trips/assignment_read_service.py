"""Read queries for driver-owned assignments and booking stop payloads."""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ForbiddenError
from app.modules.authentication.dependencies import CurrentActor
from app.modules.bookings.models import Booking
from app.modules.customers.models import CustomerProfile
from app.modules.dispatch.models import Assignment
from app.modules.drivers.models import DriverProfile
from app.modules.services.models import ServiceCategory
from app.modules.trips.models import Trip
from app.modules.trips.schemas import DriverAssignmentDetailResponse, TripResponse
from app.modules.vehicles.models import Vehicle


async def resolve_driver_profile(session: AsyncSession, actor: CurrentActor) -> DriverProfile:
    """Resolve active DriverProfile owned by current authenticated driver."""
    driver = (
        await session.execute(
            select(DriverProfile).where(
                DriverProfile.user_id == actor.user_id, DriverProfile.deleted_at.is_(None)
            )
        )
    ).scalar_one_or_none()
    if driver is None:
        raise ForbiddenError("Driver profile not found for this account.")
    return driver


class DriverAssignmentReadService:
    """Hydrates assignment detail cards owned strictly by current driver."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def list_my_assignments(
        self, actor: CurrentActor
    ) -> list[DriverAssignmentDetailResponse]:
        """List current and upcoming assignments belonging strictly to current driver."""
        driver = await resolve_driver_profile(self._session, actor)
        rows = (
            (
                await self._session.execute(
                    select(Assignment)
                    .where(Assignment.driver_id == driver.id, Assignment.is_current.is_(True))
                    .order_by(Assignment.created_at.desc())
                )
            )
            .scalars()
            .all()
        )
        results: list[DriverAssignmentDetailResponse] = []
        for a in rows:
            results.append(await self._hydrate_assignment(a))
        return results

    async def _hydrate_assignment(self, a: Assignment) -> DriverAssignmentDetailResponse:
        booking = (
            await self._session.execute(select(Booking).where(Booking.id == a.booking_id))
        ).scalar_one()
        customer = (
            await self._session.execute(
                select(CustomerProfile).where(CustomerProfile.id == booking.customer_id)
            )
        ).scalar_one()
        vehicle = (
            await self._session.execute(select(Vehicle).where(Vehicle.id == a.vehicle_id))
        ).scalar_one()
        svc = (
            await self._session.execute(
                select(ServiceCategory).where(ServiceCategory.id == booking.service_category_id)
            )
        ).scalar_one()
        trip = (
            await self._session.execute(select(Trip).where(Trip.assignment_id == a.id))
        ).scalar_one_or_none()
        steps = svc.workflow.steps_json if svc.workflow else ["assigned", "service_completed"]
        return DriverAssignmentDetailResponse(
            assignment_id=a.id,
            assignment_status=a.status,
            booking_id=booking.id,
            booking_reference=booking.reference,
            service_name=svc.name,
            workflow_steps=steps,
            pickup_at=booking.pickup_at,
            expected_end_at=booking.expected_end_at,
            customer_name=customer.full_name,
            customer_phone=customer.phone,
            vehicle_name=vehicle.name,
            vehicle_plate=vehicle.plate_number,
            stops=[
                {
                    "seq_order": s.seq_order,
                    "stop_type": s.stop_type,
                    "address": s.address,
                    "lat": float(s.lat) if s.lat is not None else None,
                    "lng": float(s.lng) if s.lng is not None else None,
                }
                for s in booking.stops
            ],
            special_instructions=booking.special_instructions,
            trip=TripResponse.model_validate(trip) if trip else None,
        )
