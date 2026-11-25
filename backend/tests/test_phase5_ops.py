"""Phase 5 integration tests: maintenance blocks, expiry reminders, CRM, reviews, and reports."""

from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.customers.models import CustomerProfile
from tests.phase5_fixtures import bootstrap_phase5_scenario


async def test_phase5_maintenance_crm_reviews_and_reports(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """Exercise maintenance 409 lock, doc expiry alerts, corporate balance, review, CSV/PDF."""
    ctx = await bootstrap_phase5_scenario(client, db_session)
    own_hdr = {"Authorization": f"Bearer {ctx['owner_token']}"}
    cust_hdr = {"Authorization": f"Bearer {ctx['cust_token']}"}
    drv_hdr = {"Authorization": f"Bearer {ctx['drv_token']}"}
    booking_id, veh_id, drv_id = ctx["booking_id"], ctx["vehicle_id"], ctx["driver_id"]

    # Overlapping maintenance against same vehicle -> 409 Conflict
    overlap_maint = await client.post(
        "/api/v1/maintenance",
        headers=own_hdr,
        json={
            "vehicle_id": veh_id,
            "maint_type": "oil_change",
            "description": "Service interval",
            "scheduled_start": "2026-12-26T10:30:00Z",
            "scheduled_end": "2026-12-26T13:00:00Z",
        },
    )
    assert overlap_maint.status_code == 409

    # Expiry scan detects vehicle doc + driver licence
    scan = (await client.post("/api/v1/maintenance/expiry-scan", headers=own_hdr)).json()
    assert scan["doc_alerts_created"] >= 1 and scan["licence_alerts_created"] >= 1

    # Corporate account + link CRM customer + comm log + corporate balance
    corp = (
        await client.post(
            "/api/v1/corporate/accounts",
            headers=own_hdr,
            json={"company_name": "Acme Corp", "negotiated_discount_bps": 1000},
        )
    ).json()
    cust_prof = (
        await db_session.execute(
            select(CustomerProfile).where(CustomerProfile.email == "corpguest@test.com")
        )
    ).scalar_one()
    await client.patch(
        f"/api/v1/crm/customers/{cust_prof.id}",
        headers=own_hdr,
        json={"corporate_id": corp["id"], "notes": "VIP corporate"},
    )
    assert (
        await client.post(
            f"/api/v1/crm/customers/{cust_prof.id}/comms",
            headers=own_hdr,
            json={"channel": "call", "summary": "Confirmed pickup gate"},
        )
    ).status_code == 201
    bal = await client.get(f"/api/v1/corporate/accounts/{corp['id']}/balance", headers=own_hdr)
    assert bal.status_code == 200 and bal.json()["active_customers"] == 1

    # Dispatch recommendations + complete trip + review + moderation + CSV/PDF export
    rec = (
        await client.get(
            f"/api/v1/dispatch/recommendations?booking_id={booking_id}", headers=own_hdr
        )
    ).json()
    assert len(rec["vehicles"]) >= 1

    assign = (
        await client.post(
            "/api/v1/dispatch/assign",
            headers=own_hdr,
            json={"booking_id": booking_id, "vehicle_id": veh_id, "driver_id": drv_id},
        )
    ).json()
    trip = (
        await client.post(f"/api/v1/driver/assignments/{assign['id']}/ack", headers=drv_hdr)
    ).json()
    await client.post(
        f"/api/v1/trips/{trip['id']}/complete",
        headers=drv_hdr,
        json={"completed_at": "2026-12-26T12:00:00Z", "end_odometer": 1200},
    )

    rev = (
        await client.post(
            "/api/v1/reviews",
            headers=cust_hdr,
            json={
                "booking_id": booking_id,
                "overall_rating": 5,
                "driver_rating": 5,
                "vehicle_rating": 5,
                "service_rating": 5,
                "comment": "Smooth ride",
            },
        )
    ).json()
    assert rev["moderation_status"] == "published"
    assert (
        await client.patch(
            f"/api/v1/reviews/{rev['id']}/moderate",
            headers=own_hdr,
            json={"moderation_status": "hidden"},
        )
    ).json()["moderation_status"] == "hidden"

    csv_exp = await client.get("/api/v1/reports/export?export_format=csv", headers=own_hdr)
    pdf_exp = await client.get("/api/v1/reports/export?export_format=pdf", headers=own_hdr)
    assert csv_exp.status_code == 200 and b"total_bookings" in csv_exp.content
    assert pdf_exp.status_code == 200 and pdf_exp.content.startswith(b"%PDF-")
