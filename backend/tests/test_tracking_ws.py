"""Integration tests for Phase 3 GPS ingestion, privacy window, tracking API, and WS ACLs."""

from datetime import UTC, datetime, timedelta

from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.modules.tracking.ws_manager import ws_hub
from app.modules.users.models import User
from app.modules.users.repository import UserRepository


async def test_gps_privacy_window_tracking_and_ws_acl(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """Verify GPS upload gated to active trip, customer isolation, playback, and WS ACLs."""
    roles = await UserRepository(db_session).get_roles_by_slugs(["owner"])
    owner = User(
        email="gpsowner@velofleet.test",
        full_name="Fleet Owner",
        password_hash=hash_password("OwnerPass!1234"),
        roles=roles,
    )
    db_session.add(owner)
    await db_session.commit()

    adm_tok = (
        await client.post(
            "/api/v1/auth/login",
            json={"identifier": "gpsowner@velofleet.test", "password": "OwnerPass!1234"},
        )
    ).json()["access_token"]
    adm_hdr = {"Authorization": f"Bearer {adm_tok}"}

    c1 = (
        await client.post(
            "/api/v1/auth/register",
            json={"full_name": "Cust One", "email": "c1@test.com", "password": "CustPass!1234"},
        )
    ).json()
    c2 = (
        await client.post(
            "/api/v1/auth/register",
            json={"full_name": "Cust Two", "email": "c2@test.com", "password": "CustPass!1234"},
        )
    ).json()
    c1_hdr = {"Authorization": f"Bearer {c1['access_token']}"}
    c2_hdr = {"Authorization": f"Bearer {c2['access_token']}"}

    veh = (
        await client.post(
            "/api/v1/vehicles",
            headers=adm_hdr,
            json={
                "plate_number": "GPS-99",
                "name": "Tracker Sedan",
                "category": "sedan",
                "make": "Honda",
                "model": "Accord",
                "year": 2025,
                "seat_capacity": 4,
                "fuel_type": "hybrid",
            },
        )
    ).json()
    drv = (
        await client.post(
            "/api/v1/drivers",
            headers=adm_hdr,
            json={
                "full_name": "Ali Chauffeur",
                "phone": "+1555888001",
                "password": "DriverPass!123",
                "licence_number": "GPS-LIC-1",
                "licence_expiry": "2028-12-31",
            },
        )
    ).json()
    drv_tok = (
        await client.post(
            "/api/v1/auth/login",
            json={"identifier": "+1555888001", "password": "DriverPass!123"},
        )
    ).json()["access_token"]
    drv_hdr = {"Authorization": f"Bearer {drv_tok}"}

    booking = (
        await client.post(
            "/api/v1/bookings",
            headers={**c1_hdr, "Idempotency-Key": "55555555-5555-4555-8555-555555555501"},
            json={
                "service_slug": "airport_transfer",
                "pickup_at": "2026-12-20T10:00:00Z",
                "expected_end_at": "2026-12-20T12:00:00Z",
                "stops": [
                    {"stop_type": "pickup", "address": "Terminal A"},
                    {"stop_type": "destination", "address": "Downtown"},
                ],
            },
        )
    ).json()
    await client.post(f"/api/v1/bookings/{booking['id']}/confirm", headers=adm_hdr, json={})
    assign = (
        await client.post(
            "/api/v1/dispatch/assign",
            headers=adm_hdr,
            json={"booking_id": booking["id"], "vehicle_id": veh["id"], "driver_id": drv["id"]},
        )
    ).json()
    trip = (
        await client.post(f"/api/v1/driver/assignments/{assign['id']}/ack", headers=drv_hdr)
    ).json()

    now_iso = datetime.now(UTC).isoformat()
    # Before en_route_to_pickup -> GPS ingestion MUST be denied with 403
    denied_early = await client.post(
        "/api/v1/tracking/locations/batch",
        headers={**drv_hdr, "Idempotency-Key": "66666666-6666-4666-8666-666666666601"},
        json={
            "assignment_id": assign["id"],
            "points": [{"lat": 23.81, "lng": 90.41, "recorded_at": now_iso}],
        },
    )
    assert denied_early.status_code == 403

    # Transition to en_route_to_pickup -> tracking window opens
    await client.post(
        f"/api/v1/trips/{trip['id']}/milestones",
        headers={**drv_hdr, "Idempotency-Key": "66666666-6666-4666-8666-666666666602"},
        json={"milestone": "en_route_to_pickup", "occurred_at": now_iso},
    )

    t1 = (datetime.now(UTC) - timedelta(seconds=20)).isoformat()
    t2 = datetime.now(UTC).isoformat()
    ingested = await client.post(
        "/api/v1/tracking/locations/batch",
        headers={**drv_hdr, "Idempotency-Key": "66666666-6666-4666-8666-666666666603"},
        json={
            "assignment_id": assign["id"],
            "points": [
                {"lat": 23.8103, "lng": 90.4125, "speed_mps": 8.0, "recorded_at": t1},
                {"lat": 23.8150, "lng": 90.4160, "speed_mps": 9.5, "recorded_at": t2},
            ],
        },
    )
    assert ingested.status_code == 200
    assert ingested.json()["freshness"] == "live"
    assert ingested.json()["persisted_count"] == 2

    # Admin live fleet map sees vehicle; Customer 1 sees own tracking; Customer 2 gets 403
    fleet_live = (await client.get("/api/v1/tracking/fleet/live", headers=adm_hdr)).json()
    assert len(fleet_live) == 1
    assert fleet_live[0]["freshness"] == "live"

    c1_track = (
        await client.get(f"/api/v1/bookings/{booking['id']}/tracking", headers=c1_hdr)
    ).json()
    assert c1_track["tracking_active"] is True
    assert c1_track["driver_display_name"] == "Ali"

    c2_track = await client.get(f"/api/v1/bookings/{booking['id']}/tracking", headers=c2_hdr)
    assert c2_track.status_code == 403

    # WS channel authorization checks
    ok_ws = await ws_hub.authorize_channel(
        channel=f"booking:{booking['id']}",
        user_id=owner.id,
        roles={"owner"},
        perms=set(),
        session=db_session,
    )
    bad_ws = await ws_hub.authorize_channel(
        channel="admin:fleet", user_id=owner.id, roles=set(), perms=set(), session=db_session
    )
    assert ok_ws is True and bad_ws is False

    # Historical route playback for admin
    route = (await client.get(f"/api/v1/tracking/trips/{trip['id']}/route", headers=adm_hdr)).json()
    assert len(route) == 2

    # Complete trip -> GPS window closes immediately
    await client.post(
        f"/api/v1/trips/{trip['id']}/complete",
        headers=drv_hdr,
        json={"completed_at": t2, "end_odometer": 5000},
    )
    denied_after = await client.post(
        "/api/v1/tracking/locations/batch",
        headers={**drv_hdr, "Idempotency-Key": "66666666-6666-4666-8666-666666666604"},
        json={
            "assignment_id": assign["id"],
            "points": [{"lat": 23.82, "lng": 90.42, "recorded_at": t2}],
        },
    )
    assert denied_after.status_code == 403
