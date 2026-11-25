"""Phase 4 integration tests: payments, refunds, PDF invoices, expenses, and RBAC."""

from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from tests.finance_fixtures import bootstrap_finance_scenario


async def test_finance_payments_refunds_invoices_expenses_rbac(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """Exercise idempotent payments, refund caps, PDF invoices, expenses, and IDOR checks."""
    ctx = await bootstrap_finance_scenario(client, db_session)
    acct_hdr = {"Authorization": f"Bearer {ctx['acct_token']}"}
    c1_hdr = {"Authorization": f"Bearer {ctx['c1_token']}"}
    c2_hdr = {"Authorization": f"Bearer {ctx['c2_token']}"}
    drv_hdr = {"Authorization": f"Bearer {ctx['drv_token']}"}
    booking_id = ctx["booking_id"]

    # Quotation GET ownership & isolation check
    assert (
        await client.get(f"/api/v1/quotations/{ctx['quotation_id']}", headers=c1_hdr)
    ).status_code == 200
    assert (
        await client.get(f"/api/v1/quotations/{ctx['quotation_id']}", headers=c2_hdr)
    ).status_code == 403

    # Record idempotent payment & verify replay returns same record
    pay_payload = {
        "booking_id": booking_id,
        "payment_type": "deposit",
        "method": "card",
        "amount_minor": 15000,
        "currency": "USD",
    }
    p1 = await client.post(
        "/api/v1/finance/payments",
        headers={**acct_hdr, "Idempotency-Key": "77777777-7777-4777-8777-777777777702"},
        json=pay_payload,
    )
    p_rep = await client.post(
        "/api/v1/finance/payments",
        headers={**acct_hdr, "Idempotency-Key": "77777777-7777-4777-8777-777777777702"},
        json=pay_payload,
    )
    assert p1.status_code == 201
    assert p_rep.json()["id"] == p1.json()["id"]

    # Customer B IDOR isolation check on booking financial summary
    assert (
        await client.get(f"/api/v1/finance/bookings/{booking_id}/summary", headers=c2_hdr)
    ).status_code == 403

    # Refund cap + RBAC + sequential PDF invoice
    assert (
        await client.post(
            "/api/v1/finance/refunds",
            headers={**acct_hdr, "Idempotency-Key": "77777777-7777-4777-8777-777777777703"},
            json={"payment_id": p1.json()["id"], "amount_minor": 20000, "reason": "Too high"},
        )
    ).status_code == 422
    assert (
        await client.post(
            "/api/v1/finance/refunds",
            headers={**acct_hdr, "Idempotency-Key": "77777777-7777-4777-8777-777777777704"},
            json={"payment_id": p1.json()["id"], "amount_minor": 3000, "reason": "Partial refund"},
        )
    ).status_code == 201

    inv = await client.post(
        f"/api/v1/finance/bookings/{booking_id}/invoices",
        headers=acct_hdr,
        json={"tax_minor": 1000},
    )
    assert inv.status_code == 201
    pdf_resp = await client.get(f"/api/v1/finance/invoices/{inv.json()['id']}/pdf", headers=c1_hdr)
    assert pdf_resp.status_code == 200
    assert pdf_resp.content.startswith(b"%PDF-")

    # Driver expense submission + accountant approval + cash-flow summary
    exp = await client.post(
        "/api/v1/finance/expenses",
        headers=drv_hdr,
        json={
            "booking_id": booking_id,
            "category": "toll",
            "amount_minor": 1200,
            "incurred_at": "2026-12-22T12:00:00Z",
            "description": "Bridge toll",
        },
    )
    assert exp.status_code == 201
    decided = await client.post(
        f"/api/v1/finance/expenses/{exp.json()['id']}/decision",
        headers=acct_hdr,
        json={"status": "approved", "review_notes": "Valid receipt"},
    )
    assert decided.json()["status"] == "approved"

    period = (await client.get("/api/v1/finance/summary", headers=acct_hdr)).json()
    assert period["cash_collected_minor"] == 15000
    assert period["refunded_minor"] == 3000
    assert period["approved_expenses_minor"] == 1200
    assert period["net_cash_flow_minor"] == 10800
