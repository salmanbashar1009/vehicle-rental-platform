"""Helper to idempotently seed a sample booking and dispatch assignment for demo testing."""

from datetime import UTC, datetime, timedelta

from asyncpg.types import Range
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.bookings.models import Booking, BookingStop
from app.modules.customers.models import CustomerProfile
from app.modules.dispatch.models import Assignment
from app.modules.drivers.models import DriverProfile, DriverScheduleBlock
from app.modules.services.models import ServiceCategory
from app.modules.vehicles.models import Vehicle, VehicleScheduleBlock

DEMO_BOOKING_REF = "VF-DEMO-1001"


async def ensure_demo_assignment(session: AsyncSession, driver: DriverProfile) -> None:
    """Create a sample dispatched booking and schedule blocks if missing."""
    existing = (
        await session.execute(select(Booking).where(Booking.reference == DEMO_BOOKING_REF))
    ).scalar_one_or_none()
    if existing is not None:
        return

    svc = (
        await session.execute(
            select(ServiceCategory).where(ServiceCategory.slug == "airport_transfer")
        )
    ).scalar_one_or_none()
    vehicle = (
        await session.execute(select(Vehicle).where(Vehicle.plate_number == "VF-EXEC-101"))
    ).scalar_one_or_none()
    if svc is None or vehicle is None:
        return

    customer = CustomerProfile(
        customer_type="individual",
        full_name="Elena Rostova",
        email="elena.rostova@example.com",
        phone="+15550194400",
    )
    session.add(customer)
    await session.flush()

    pickup_at = datetime.now(UTC) + timedelta(minutes=30)
    expected_end_at = pickup_at + timedelta(hours=2)
    booking = Booking(
        reference=DEMO_BOOKING_REF,
        customer_id=customer.id,
        service_category_id=svc.id,
        preferred_vehicle_id=vehicle.id,
        status="dispatched",
        pickup_at=pickup_at,
        expected_end_at=expected_end_at,
        passenger_count=2,
        luggage_count=3,
        special_instructions="Flight BA117 arrival; meet at Terminal 4 VIP exit.",
    )
    session.add(booking)
    await session.flush()

    session.add_all(
        [
            BookingStop(
                booking_id=booking.id,
                seq_order=1,
                stop_type="pickup",
                address="JFK Terminal 4 Arrivals, Queens, NY",
                lat=40.641300,
                lng=-73.778100,
            ),
            BookingStop(
                booking_id=booking.id,
                seq_order=2,
                stop_type="dropoff",
                address="Midtown Manhattan Hotel, New York, NY",
                lat=40.758000,
                lng=-73.985500,
            ),
        ]
    )
    session.add(
        Assignment(
            booking_id=booking.id,
            vehicle_id=vehicle.id,
            driver_id=driver.id,
            status="pending_ack",
            is_current=True,
        )
    )
    window = Range(pickup_at, expected_end_at, lower_inc=True, upper_inc=False)
    session.add(
        VehicleScheduleBlock(
            vehicle_id=vehicle.id, block_type="assignment", source_id=booking.id, time_range=window
        )
    )
    session.add(
        DriverScheduleBlock(
            driver_id=driver.id, block_type="assignment", source_id=booking.id, time_range=window
        )
    )
