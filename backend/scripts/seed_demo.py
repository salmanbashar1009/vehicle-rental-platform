"""Development-only seeder for demo admin and driver sign-in credentials."""

import argparse
import asyncio
import os
import sys
from datetime import date, timedelta
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.core.config import get_settings  # noqa: E402
from app.core.security import hash_password  # noqa: E402
from app.database.session import dispose_engine, get_session_factory  # noqa: E402
from app.modules.drivers.models import DriverProfile  # noqa: E402
from app.modules.services.seed import seed_service_categories  # noqa: E402
from app.modules.users.models import User  # noqa: E402
from app.modules.users.repository import UserRepository  # noqa: E402
from app.modules.users.seed import seed_roles_and_permissions  # noqa: E402
from app.modules.vehicles.seed import seed_sample_vehicles  # noqa: E402
from scripts.seed_demo_assignment import ensure_demo_assignment  # noqa: E402

DEMO_ADMIN_EMAIL = "admin@velofleet.local"
DEMO_ADMIN_PHONE = "+15550101001"
DEMO_DRIVER_EMAIL = "driver@velofleet.local"
DEMO_DRIVER_PHONE = "+15550102001"


async def _upsert_user(
    session: AsyncSession,
    *,
    email: str,
    phone: str,
    full_name: str,
    role_slug: str,
    password: str,
) -> User:
    repo = UserRepository(session)
    user = await repo.get_by_identifier(email)
    roles = await repo.get_roles_by_slugs([role_slug])
    if user is None:
        user = User(
            email=email,
            phone=phone,
            full_name=full_name,
            password_hash=hash_password(password),
            is_active=True,
            roles=roles,
        )
        session.add(user)
    else:
        user.password_hash = hash_password(password)
        user.is_active = True
        if not any(r.slug == role_slug for r in user.roles):
            user.roles = roles
    await session.flush()
    return user


async def _ensure_demo_driver(session: AsyncSession, password: str) -> DriverProfile:
    user = await _upsert_user(
        session,
        email=DEMO_DRIVER_EMAIL,
        phone=DEMO_DRIVER_PHONE,
        full_name="Marcus Vance",
        role_slug="driver",
        password=password,
    )
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


async def seed_demo_data(driver_password: str, admin_password: str | None = None) -> None:
    """Seed base lookup data, demo staff/driver credentials, and a sample assignment."""
    admin_pw = admin_password or driver_password
    if get_settings().app_env != "development":
        raise RuntimeError("Demo seeding is restricted to APP_ENV=development.")
    if len(driver_password) < 10 or len(admin_pw) < 10:
        raise ValueError("Demo passwords must be at least 10 characters.")

    async with get_session_factory()() as session:
        await seed_roles_and_permissions(session)
        await seed_service_categories(session)
        await seed_sample_vehicles(session)
        await _upsert_user(
            session,
            email=DEMO_ADMIN_EMAIL,
            phone=DEMO_ADMIN_PHONE,
            full_name="VeloFleet Admin",
            role_slug="owner",
            password=admin_pw,
        )
        driver = await _ensure_demo_driver(session, driver_password)
        await ensure_demo_assignment(session, driver)
        await session.commit()
    await dispose_engine()


def main() -> None:
    parser = argparse.ArgumentParser(description="Seed local development demo accounts.")
    parser.add_argument("--password", default=os.getenv("DEV_DEMO_PASSWORD", ""))
    parser.add_argument("--admin-password", default=os.getenv("DEV_DEMO_ADMIN_PASSWORD", ""))
    args = parser.parse_args()
    if not args.password:
        raise SystemExit("Pass --password or set DEV_DEMO_PASSWORD (min 10 chars).")
    asyncio.run(seed_demo_data(args.password, args.admin_password or None))
    print(f"Demo accounts seeded: {DEMO_ADMIN_EMAIL}, {DEMO_DRIVER_EMAIL}")


if __name__ == "__main__":
    main()
