"""Integration and concurrency tests for bookings, quotations, and zero-conflict dispatch."""

import asyncio

from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.modules.users.models import User
from app.modules.users.repository import UserRepository


async def _login_owner(client: AsyncClient, db_session: AsyncSession) -> str:
    roles = await UserRepository(db_session).get_roles_by_slugs(["owner"])
    db_session.add(
        User(
            email="admin@velofleet.test",
            full_name="Admin User",
            password_hash=hash_password("AdminPass!1234"),
            roles=roles,
        )
    )
    await db_session.commit()
    res = await client.post(
        "/api/v1/auth/login",
        json={"identifier": "admin@velofleet.test", "password": "AdminPass!1234"},
    )
    return str(res.json()["access_token"])


async def test_parallel_dispatch_prevents_double_booking(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """Two overlapping assignments on the same vehicle must yield one 201 and one 409."""
    admin_tok = await _login_owner(client, db_session)
    hdr = {"Authorization": f"Bearer {admin_tok}"}

    veh = (
        await client.post(
            "/api/v1/vehicles",
            headers=hdr,
            json={
                "plate_number": "VF-1001",
                "name": "Executive Sedan",
                "category": "sedan",
                "make": "Toyota",
                "model": "Camry",
                "year": 2025,
                "seat_capacity": 4,
                "luggage_capacity": 3,
                "fuel_type": "hybrid",
            },
        )
    ).json()
    drv = (
        await client.post(
            "/api/v1/drivers",
            headers=hdr,
            json={
                "full_name": "John Chauffeur",
                "phone": "+1555010101",
                "password": "DriverPass!123",
                "licence_number": "LIC-99001",
                "licence_expiry": "2028-12-31",
            },
        )
    ).json()

    b1 = (
        await client.post(
            "/api/v1/bookings",
            headers={"Idempotency-Key": "22222222-2222-4222-8222-222222222221"},
            json={
                "service_slug": "personal_transport",
                "pickup_at": "2026-12-10T09:00:00Z",
                "expected_end_at": "2026-12-10T13:00:00Z",
                "customer_name": "Guest One",
                "customer_phone": "+15550001",
                "stops": [
                    {"stop_type": "pickup", "address": "Point A"},
                    {"stop_type": "destination", "address": "Point B"},
                ],
            },
        )
    ).json()
    b2 = (
        await client.post(
            "/api/v1/bookings",
            headers={"Idempotency-Key": "22222222-2222-4222-8222-222222222222"},
            json={
                "service_slug": "personal_transport",
                "pickup_at": "2026-12-10T11:00:00Z",
                "expected_end_at": "2026-12-10T15:00:00Z",
                "customer_name": "Guest Two",
                "customer_phone": "+15550002",
                "stops": [
                    {"stop_type": "pickup", "address": "Point C"},
                    {"stop_type": "destination", "address": "Point D"},
                ],
            },
        )
    ).json()

    assert (
        await client.post(f"/api/v1/bookings/{b1['id']}/confirm", headers=hdr, json={})
    ).status_code == 200
    assert (
        await client.post(f"/api/v1/bookings/{b2['id']}/confirm", headers=hdr, json={})
    ).status_code == 200

    r1, r2 = await asyncio.gather(
        client.post(
            "/api/v1/dispatch/assign",
            headers=hdr,
            json={"booking_id": b1["id"], "vehicle_id": veh["id"], "driver_id": drv["id"]},
        ),
        client.post(
            "/api/v1/dispatch/assign",
            headers=hdr,
            json={"booking_id": b2["id"], "vehicle_id": veh["id"], "driver_id": drv["id"]},
        ),
    )
    codes = sorted([r1.status_code, r2.status_code])
    assert codes == [201, 409]
