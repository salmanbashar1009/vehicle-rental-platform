"""Integration tests for authentication, refresh rotation, RBAC, and anti-IDOR."""

from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.modules.users.models import User
from app.modules.users.repository import UserRepository


async def test_register_login_refresh_and_reuse_revocation(client: AsyncClient) -> None:
    """Verify full auth lifecycle and refresh-token reuse detection."""
    reg = await client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Alice Customer",
            "email": "alice@example.com",
            "password": "StrongPassword!123",
        },
    )
    assert reg.status_code == 201
    tokens1 = reg.json()
    assert tokens1["user"]["roles"] == ["customer"]

    ref = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": tokens1["refresh_token"]},
    )
    assert ref.status_code == 200
    tokens2 = ref.json()
    assert tokens2["refresh_token"] != tokens1["refresh_token"]

    # Replay old rotated refresh token -> must revoke entire family
    reuse = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": tokens1["refresh_token"]},
    )
    assert reuse.status_code == 401

    # Subsequent attempt with tokens2 must also fail because family was revoked
    after_rev = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": tokens2["refresh_token"]},
    )
    assert after_rev.status_code == 401


async def test_rbac_matrix_and_customer_idor_isolation(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """Verify customers cannot access staff routes or another customer's bookings."""
    cust_a = await client.post(
        "/api/v1/auth/register",
        json={"full_name": "Cust A", "email": "ca@example.com", "password": "StrongPassword!123"},
    )
    cust_b = await client.post(
        "/api/v1/auth/register",
        json={"full_name": "Cust B", "email": "cb@example.com", "password": "StrongPassword!123"},
    )
    tok_a = cust_a.json()["access_token"]
    tok_b = cust_b.json()["access_token"]

    # Customer A cannot hit staff /users endpoint
    forbidden = await client.get("/api/v1/users", headers={"Authorization": f"Bearer {tok_a}"})
    assert forbidden.status_code == 403

    # Seed an owner and confirm customer A creates booking, customer B cannot read it
    owner_roles = await UserRepository(db_session).get_roles_by_slugs(["owner"])
    db_session.add(
        User(
            email="owner@velofleet.test",
            full_name="Platform Owner",
            password_hash=hash_password("OwnerPass!1234"),
            roles=owner_roles,
        )
    )
    await db_session.commit()

    created = await client.post(
        "/api/v1/bookings",
        headers={
            "Authorization": f"Bearer {tok_a}",
            "Idempotency-Key": "11111111-1111-4111-8111-111111111111",
        },
        json={
            "service_slug": "airport_transfer",
            "pickup_at": "2026-12-01T10:00:00Z",
            "expected_end_at": "2026-12-01T12:00:00Z",
            "passenger_count": 2,
            "stops": [
                {"stop_type": "pickup", "address": "Terminal 1"},
                {"stop_type": "destination", "address": "Grand Hotel"},
            ],
        },
    )
    assert created.status_code == 201
    booking_id = created.json()["id"]

    idor = await client.get(
        f"/api/v1/bookings/{booking_id}",
        headers={"Authorization": f"Bearer {tok_b}"},
    )
    assert idor.status_code == 403
