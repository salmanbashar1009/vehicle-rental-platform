"""Integration tests for Phase 2 driver operations, workflows, incidents, and notifications."""

from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.modules.users.models import User
from app.modules.users.repository import UserRepository


async def _setup_admin_and_drivers(
    client: AsyncClient, db_session: AsyncSession
) -> tuple[dict[str, str], dict[str, str], dict[str, str], str, str, str]:
    roles = await UserRepository(db_session).get_roles_by_slugs(["owner"])
    db_session.add(
        User(
            email="ops@velofleet.test",
            full_name="Ops Owner",
            password_hash=hash_password("OpsPass!12345"),
            roles=roles,
        )
    )
    await db_session.commit()
    adm = (
        await client.post(
            "/api/v1/auth/login",
            json={"identifier": "ops@velofleet.test", "password": "OpsPass!12345"},
        )
    ).json()
    adm_hdr = {"Authorization": f"Bearer {adm['access_token']}"}

    veh = (
        await client.post(
            "/api/v1/vehicles",
            headers=adm_hdr,
            json={
                "plate_number": "CARGO-77",
                "name": "Box Cargo Van",
                "category": "cargo",
                "make": "Isuzu",
                "model": "NPR",
                "year": 2025,
                "seat_capacity": 3,
                "fuel_type": "diesel",
            },
        )
    ).json()
    d1 = (
        await client.post(
            "/api/v1/drivers",
            headers=adm_hdr,
            json={
                "full_name": "Driver One",
                "phone": "+1555111001",
                "password": "DriverPass!123",
                "licence_number": "DRV-111",
                "licence_expiry": "2028-12-31",
            },
        )
    ).json()
    d2 = (
        await client.post(
            "/api/v1/drivers",
            headers=adm_hdr,
            json={
                "full_name": "Driver Two",
                "phone": "+1555111002",
                "password": "DriverPass!123",
                "licence_number": "DRV-222",
                "licence_expiry": "2028-12-31",
            },
        )
    ).json()
    d1_tok = (
        await client.post(
            "/api/v1/auth/login",
            json={"identifier": "+1555111001", "password": "DriverPass!123"},
        )
    ).json()["access_token"]
    d2_tok = (
        await client.post(
            "/api/v1/auth/login",
            json={"identifier": "+1555111002", "password": "DriverPass!123"},
        )
    ).json()["access_token"]

    booking = (
        await client.post(
            "/api/v1/bookings",
            headers={"Idempotency-Key": "33333333-3333-4333-8333-333333333301"},
            json={
                "service_slug": "house_shifting_cargo",
                "pickup_at": "2026-12-15T08:00:00Z",
                "expected_end_at": "2026-12-15T16:00:00Z",
                "customer_name": "Mover Client",
                "customer_phone": "+1555999000",
                "stops": [
                    {"stop_type": "pickup", "address": "Apt 4B"},
                    {"stop_type": "destination", "address": "New House"},
                ],
            },
        )
    ).json()
    await client.post(f"/api/v1/bookings/{booking['id']}/confirm", headers=adm_hdr, json={})
    assign = (
        await client.post(
            "/api/v1/dispatch/assign",
            headers=adm_hdr,
            json={"booking_id": booking["id"], "vehicle_id": veh["id"], "driver_id": d1["id"]},
        )
    ).json()
    return (
        adm_hdr,
        {"Authorization": f"Bearer {d1_tok}"},
        {"Authorization": f"Bearer {d2_tok}"},
        booking["id"],
        assign["id"],
        d2["id"],
    )


async def test_driver_cargo_workflow_idor_and_completion(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """Verify cargo workflow steps, driver IDOR isolation, incident alert, and completion."""
    adm_hdr, d1_hdr, d2_hdr, _, assign_id, _ = await _setup_admin_and_drivers(client, db_session)

    # Driver 2 cannot acknowledge Driver 1's assignment
    forbidden = await client.post(f"/api/v1/driver/assignments/{assign_id}/ack", headers=d2_hdr)
    assert forbidden.status_code == 403

    # Driver 1 sees assignment with House Shifting steps (loading_started/unloading_completed)
    inbox = (await client.get("/api/v1/driver/assignments", headers=d1_hdr)).json()
    assert len(inbox) == 1
    assert "loading_started" in inbox[0]["workflow_steps"]

    trip = (await client.post(f"/api/v1/driver/assignments/{assign_id}/ack", headers=d1_hdr)).json()
    trip_id = trip["id"]

    # Skipping steps must fail with 422
    bad_step = await client.post(
        f"/api/v1/trips/{trip_id}/milestones",
        headers={**d1_hdr, "Idempotency-Key": "44444444-4444-4444-8444-444444444401"},
        json={"milestone": "journey_started", "occurred_at": "2026-12-15T08:10:00Z"},
    )
    assert bad_step.status_code == 422

    steps = [
        "en_route_to_pickup",
        "arrived_at_pickup",
        "loading_started",
        "loading_completed",
        "picked_up",
        "journey_started",
        "at_destination",
        "unloading_started",
        "unloading_completed",
    ]
    for idx, step in enumerate(steps):
        res = await client.post(
            f"/api/v1/trips/{trip_id}/milestones",
            headers={**d1_hdr, "Idempotency-Key": f"44444444-4444-4444-8444-44444444441{idx}"},
            json={"milestone": step, "occurred_at": f"2026-12-15T08:1{idx}:00Z"},
        )
        assert res.status_code == 200

    inc = await client.post(
        f"/api/v1/trips/{trip_id}/incidents",
        headers=d1_hdr,
        json={"category": "breakdown", "severity": "high", "description": "Minor tyre puncture"},
    )
    assert inc.status_code == 201
    assert len((await client.get("/api/v1/notifications", headers=adm_hdr)).json()) >= 1

    done = await client.post(
        f"/api/v1/trips/{trip_id}/complete",
        headers=d1_hdr,
        json={"completed_at": "2026-12-15T15:30:00Z", "end_odometer": 12450, "waiting_minutes": 15},
    )
    assert done.status_code == 200
    assert done.json()["status"] == "service_completed"


async def test_driver_decline_releases_booking_and_notifies_dispatcher(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """Declining an assignment returns booking to confirmed and notifies dispatcher."""
    adm_hdr, d1_hdr, _, booking_id, assign_id, _ = await _setup_admin_and_drivers(
        client, db_session
    )
    dec = await client.post(
        f"/api/v1/driver/assignments/{assign_id}/decline",
        headers=d1_hdr,
        json={"reason": "Medical emergency"},
    )
    assert dec.status_code == 204
    booking = (await client.get(f"/api/v1/bookings/{booking_id}", headers=adm_hdr)).json()
    assert booking["status"] == "confirmed"
    notifs = (await client.get("/api/v1/notifications", headers=adm_hdr)).json()
    assert any(n["event_type"] == "assignment.declined" for n in notifs)
