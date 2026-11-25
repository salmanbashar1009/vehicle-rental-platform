"""Shared Phase 4 integration setup helper creating staff, driver, customer, and booking."""

from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.modules.users.models import User
from app.modules.users.repository import UserRepository


async def bootstrap_finance_scenario(
    client: AsyncClient, db_session: AsyncSession
) -> dict[str, str]:
    """Seed accountant, owner, customer, driver, vehicle, and confirmed assigned booking."""
    acct_roles = await UserRepository(db_session).get_roles_by_slugs(["accountant"])
    own_roles = await UserRepository(db_session).get_roles_by_slugs(["owner"])
    acct = User(
        email="acct@vf.test",
        full_name="Acct",
        password_hash=hash_password("AcctPass!1234"),
        roles=acct_roles,
    )
    owner = User(
        email="finowner@vf.test",
        full_name="Owner",
        password_hash=hash_password("OwnerPass!1234"),
        roles=own_roles,
    )
    db_session.add_all([acct, owner])
    await db_session.commit()

    acct_t = (
        await client.post(
            "/api/v1/auth/login", json={"identifier": "acct@vf.test", "password": "AcctPass!1234"}
        )
    ).json()["access_token"]
    own_t = (
        await client.post(
            "/api/v1/auth/login",
            json={"identifier": "finowner@vf.test", "password": "OwnerPass!1234"},
        )
    ).json()["access_token"]

    c1 = (
        await client.post(
            "/api/v1/auth/register",
            json={"full_name": "Cust A", "email": "ca@test.com", "password": "CustPass!1234"},
        )
    ).json()["access_token"]
    c2 = (
        await client.post(
            "/api/v1/auth/register",
            json={"full_name": "Cust B", "email": "cb@test.com", "password": "CustPass!1234"},
        )
    ).json()["access_token"]

    own_hdr = {"Authorization": f"Bearer {own_t}"}
    veh = (
        await client.post(
            "/api/v1/vehicles",
            headers=own_hdr,
            json={
                "plate_number": "FIN-100",
                "name": "Exec Van",
                "category": "van",
                "make": "MB",
                "model": "V-Class",
                "year": 2025,
                "seat_capacity": 7,
                "fuel_type": "diesel",
            },
        )
    ).json()
    drv = (
        await client.post(
            "/api/v1/drivers",
            headers=own_hdr,
            json={
                "full_name": "Driver Fin",
                "phone": "+1555999001",
                "password": "DriverPass!123",
                "licence_number": "FIN-LIC-1",
                "licence_expiry": "2028-12-31",
            },
        )
    ).json()
    drv_t = (
        await client.post(
            "/api/v1/auth/login", json={"identifier": "+1555999001", "password": "DriverPass!123"}
        )
    ).json()["access_token"]

    booking = (
        await client.post(
            "/api/v1/bookings",
            headers={
                "Authorization": f"Bearer {c1}",
                "Idempotency-Key": "77777777-7777-4777-8777-777777777701",
            },
            json={
                "service_slug": "corporate_transport",
                "pickup_at": "2026-12-22T09:00:00Z",
                "expected_end_at": "2026-12-22T15:00:00Z",
                "stops": [
                    {"stop_type": "pickup", "address": "HQ"},
                    {"stop_type": "destination", "address": "Expo"},
                ],
            },
        )
    ).json()
    quote = (
        await client.post(
            f"/api/v1/bookings/{booking['id']}/quotations",
            headers=own_hdr,
            json={
                "items": [{"label": "Chauffeur", "quantity": 1, "unit_amount_minor": 30000}],
                "discount_minor": 2000,
                "tax_minor": 0,
                "deposit_minor": 10000,
                "currency": "USD",
                "valid_until": "2026-12-21T00:00:00Z",
            },
        )
    ).json()
    await client.post(
        f"/api/v1/quotations/{quote['id']}/accept", headers={"Authorization": f"Bearer {c1}"}
    )
    await client.post(f"/api/v1/bookings/{booking['id']}/confirm", headers=own_hdr, json={})
    await client.post(
        "/api/v1/dispatch/assign",
        headers=own_hdr,
        json={"booking_id": booking["id"], "vehicle_id": veh["id"], "driver_id": drv["id"]},
    )
    return {
        "acct_token": acct_t,
        "c1_token": c1,
        "c2_token": c2,
        "drv_token": drv_t,
        "booking_id": booking["id"],
        "quotation_id": quote["id"],
    }
