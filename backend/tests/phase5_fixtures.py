"""Shared Phase 5 integration setup helper creating owner, customer, vehicle, doc, driver."""

from datetime import UTC, datetime, timedelta

from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.modules.users.models import User
from app.modules.users.repository import UserRepository
from app.modules.vehicles.models import VehicleDocument


async def bootstrap_phase5_scenario(
    client: AsyncClient, db_session: AsyncSession
) -> dict[str, str]:
    """Seed Phase 5 entities including soon-expiring vehicle document and driver licence."""
    own_roles = await UserRepository(db_session).get_roles_by_slugs(["owner"])
    owner = User(
        email="ops5owner@vf.test",
        full_name="Ops Owner",
        password_hash=hash_password("OwnerPass!1234"),
        roles=own_roles,
    )
    db_session.add(owner)
    await db_session.commit()

    own_t = (
        await client.post(
            "/api/v1/auth/login",
            json={"identifier": "ops5owner@vf.test", "password": "OwnerPass!1234"},
        )
    ).json()["access_token"]
    own_hdr = {"Authorization": f"Bearer {own_t}"}

    cust_tok = (
        await client.post(
            "/api/v1/auth/register",
            json={
                "full_name": "Corp Guest",
                "email": "corpguest@test.com",
                "password": "CustPass!1234",
            },
        )
    ).json()["access_token"]

    veh = (
        await client.post(
            "/api/v1/vehicles",
            headers=own_hdr,
            json={
                "plate_number": "MNT-500",
                "name": "Maint Sedan",
                "category": "sedan",
                "make": "Toyota",
                "model": "Camry",
                "year": 2025,
                "seat_capacity": 4,
                "fuel_type": "hybrid",
            },
        )
    ).json()

    soon = datetime.now(UTC).date() + timedelta(days=10)
    db_session.add(
        VehicleDocument(
            vehicle_id=veh["id"],
            doc_type="insurance",
            doc_number="INS-99",
            expires_at=soon,
        )
    )
    await db_session.commit()

    drv = (
        await client.post(
            "/api/v1/drivers",
            headers=own_hdr,
            json={
                "full_name": "Expiring Driver",
                "phone": "+1555777001",
                "password": "DriverPass!123",
                "licence_number": "EXP-LIC-1",
                "licence_expiry": soon.isoformat(),
            },
        )
    ).json()
    drv_tok = (
        await client.post(
            "/api/v1/auth/login",
            json={"identifier": "+1555777001", "password": "DriverPass!123"},
        )
    ).json()["access_token"]

    booking = (
        await client.post(
            "/api/v1/bookings",
            headers={
                "Authorization": f"Bearer {cust_tok}",
                "Idempotency-Key": "88888888-8888-4888-8888-888888888801",
            },
            json={
                "service_slug": "airport_transfer",
                "pickup_at": "2026-12-26T10:00:00Z",
                "expected_end_at": "2026-12-26T12:00:00Z",
                "stops": [
                    {"stop_type": "pickup", "address": "Airport"},
                    {"stop_type": "destination", "address": "Hotel"},
                ],
            },
        )
    ).json()
    await client.post(
        f"/api/v1/bookings/{booking['id']}/confirm",
        headers=own_hdr,
        json={"vehicle_id": veh["id"]},
    )
    return {
        "owner_token": own_t,
        "cust_token": cust_tok,
        "drv_token": drv_tok,
        "vehicle_id": veh["id"],
        "driver_id": drv["id"],
        "booking_id": booking["id"],
    }
