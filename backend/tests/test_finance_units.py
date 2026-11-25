"""Unit tests for Phase 4 PDF invoice generation and strict minor-unit finance schemas."""

from datetime import UTC, datetime
from uuid import uuid4

import pytest
from pydantic import ValidationError

from app.modules.finance.pdf_generator import build_invoice_pdf_bytes
from app.modules.finance.schemas import PaymentCreateRequest


def test_invoice_pdf_generator_and_payment_schema() -> None:
    """Verify valid PDF bytes and strict integer minor-unit schema validation."""
    pdf = build_invoice_pdf_bytes(
        invoice_number="INV-2026-000001",
        booking_reference="VF-2026-1000",
        customer_name="Jane Doe",
        issued_at_iso=datetime.now(UTC).isoformat(),
        currency="USD",
        agreed_minor=25000,
        extra_minor=2500,
        discount_minor=1000,
        tax_minor=500,
        total_minor=27000,
        status="issued",
    )
    assert pdf.startswith(b"%PDF-1.4")
    assert b"INV-2026-000001" in pdf
    assert pdf.rstrip().endswith(b"%%EOF")

    with pytest.raises(ValidationError):
        PaymentCreateRequest(
            booking_id=uuid4(),
            payment_type="deposit",
            method="card",
            amount_minor=0,
        )
