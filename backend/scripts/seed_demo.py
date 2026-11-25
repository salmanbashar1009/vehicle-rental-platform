"""Development-only seeder for demo driver sign-in and sample assignment."""

import argparse
import asyncio
import os
import sys
from datetime import UTC, date, datetime, timedelta
from pathlib import Path

from asyncpg.types import Range
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.core.config import get_settings  # noqa: E402
from app.core.security import hash_password  # noqa: E402
from app.database.session import dispose_engine, get_session_factory  # noqa: E402
from app.modules.bookings.models import Booking, BookingStop  # noqa: E402
from app.modules.customers.models import CustomerProfile  # noqa: E402
from app.modules.dispatch.models import Assignment  # noqa: E402
from app.modules.drivers.models import DriverProfile, DriverScheduleBlock  # noqa: E402
from app.modules.services.models import ServiceCategory  # noqa: E402
from app.modules.services.seed import seed_service_categories  # noqa: E402
from app.modules.users.models import User  # noqa: E402
from app.modules.users.repository import UserRepository  # noqa: E402
from app.modules.users.seed import seed_roles_and_permissions  # noqa: E402
from app.modules.vehicles.models import Vehicle, VehicleScheduleBlock  # noqa: E402
from app.modules.vehicles.seed import seed_sample_vehicles  # noqa: E402

DEMO_DRIVER_EMAIL = "driver@velofleet.local"
DEMO_DRIVER_PHONE = "+15550102001"
DEMO_BOOKING_REF = "VF-DEMO-1001"


async def _ensure_demo_driver(session: AsyncSession, password: str) -> DriverProfile:
    repo = UserRepository(session)
    user = await repo.get_by_identifier(DEMO_DRIVER_EMAIL)
    roles = await repo.get_roles_by_slugs(["driver"])
    if user is None:
        user = User(
            email=DEMO_DRIVER_EMAIL,
            phone=DEMO_DRIVER_PHONE,
            full_name="Marcus Vance",
            password_hash=hash_password(password),
            is_active=True,
            roles=roles,
        )
        session.add(user)
        await session.flush()
    else:
        user.password_hash = hash_password(password)
        user.is_active = True
        if not any(r.slug == "driver" for r in user.roles):
            user.roles = roles
        await session.flush()

    profile = (
        await session.execute(select(DriverProfile).where(DriverProfile.user_id == user.id))
    ).scalar_one_or_none()
    if profile is None:
        profile = DriverProfile(
            user_id=user.id,
            licence_number="DL-VF-90421",
            licence_classes_json=["sedan", "suv", "van"],
            licence_expiry=date.today() + timedelta(days=365),
            emergency_contact_name="Dispatcher Desk",
            emergency_contact_phone="+15550100001",
            availability_status="available",
        )
        session.add(profile)
        await session.flush()
    return profile


async def _ensure_demo_assignment(session: AsyncSession, driver: DriverProfile) -> None:
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


async def seed_demo_data(password: str) -> None:
    """Seed base lookup data, demo driver credentials, and an active assignment."""
    if get_settings().app_env != "development":
        raise RuntimeError("Demo seeding is restricted to APP_ENV=development.")
    if len(password) < 10:
        raise ValueError("Demo password must be at least 10 characters.")

    async with get_session_factory()() as session:
        await seed_roles_and_permissions(session)
        await seed_service_categories(session)
        await seed_sample_vehicles(session)
        driver = await _ensure_demo_driver(session, password)
        await _ensure_demo_assignment(session, driver)
        await session.commit()
    await dispose_engine()


def main() -> None:
    parser = argparse.ArgumentParser(description="Seed local development demo driver data.")
    parser.add_argument("--password", default=os.getenv("DEV_DEMO_PASSWORD", ""))
    args = parser.parse_args()
    if not args.password:
        raise SystemExit("Pass --password or set DEV_DEMO_PASSWORD (min 10 chars).")
    asyncio.run(seed_demo_data(args.password))
    print(f"Demo driver seeded: {DEMO_DRIVER_EMAIL} / {DEMO_DRIVER_PHONE}")


if __name__ == "__main__":
    main()
