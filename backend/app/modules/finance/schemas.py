"""Strict Pydantic v2 schemas for invoices, payments, refunds, expenses, and summaries."""

from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class PaymentCreateRequest(BaseModel):
    """Idempotent payment recording request."""

    model_config = ConfigDict(extra="forbid")

    booking_id: UUID
    invoice_id: UUID | None = None
    payment_type: str = Field(..., pattern=r"^(deposit|partial|full|extra_charge)$")
    method: str = Field(..., pattern=r"^(cash|bank_transfer|card|online_gateway)$")
    amount_minor: int = Field(..., gt=0)
    currency: str = Field(default="USD", min_length=3, max_length=3)
    transaction_ref: str | None = Field(default=None, max_length=128)
    reconciliation_status: str | None = Field(
        default=None, pattern=r"^(pending|reconciled|disputed)$"
    )
    notes: str | None = Field(default=None, max_length=1000)


class PaymentReconcileRequest(BaseModel):
    """Staff status update for reconciling/disputing a payment."""

    model_config = ConfigDict(extra="forbid")

    reconciliation_status: str = Field(..., pattern=r"^(pending|reconciled|disputed)$")
    notes: str | None = Field(default=None, max_length=500)


class PaymentResponse(BaseModel):
    """Serialized immutable payment row."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    booking_id: UUID
    invoice_id: UUID | None
    payment_type: str
    method: str
    amount_minor: int
    currency: str
    transaction_ref: str | None
    reconciliation_status: str
    recorded_by: UUID
    notes: str | None
    created_at: datetime


class RefundCreateRequest(BaseModel):
    """Accountant/Owner refund request linked to payment and booking."""

    model_config = ConfigDict(extra="forbid")

    payment_id: UUID
    amount_minor: int = Field(..., gt=0)
    reason: str = Field(..., min_length=3, max_length=1000)


class RefundResponse(BaseModel):
    """Serialized immutable refund row."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    payment_id: UUID
    booking_id: UUID
    amount_minor: int
    currency: str
    reason: str
    status: str
    approved_by: UUID
    created_at: datetime


class InvoiceCreateRequest(BaseModel):
    """Generate sequential invoice for a booking."""

    model_config = ConfigDict(extra="forbid")

    tax_minor: int = Field(default=0, ge=0)
    discount_minor: int = Field(default=0, ge=0)
    notes: str | None = Field(default=None, max_length=1000)


class InvoiceResponse(BaseModel):
    """Serialized customer invoice."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    booking_id: UUID
    invoice_number: str
    agreed_minor: int
    extra_minor: int
    discount_minor: int
    tax_minor: int
    total_minor: int
    currency: str
    line_items_json: list[dict[str, Any]]
    status: str
    issued_at: datetime


class BookingFinancialSummary(BaseModel):
    """Cash flow vs recognized booking value breakdown (`FIN-003`)."""

    booking_id: UUID
    booking_reference: str
    currency: str
    quoted_minor: int
    agreed_minor: int
    extra_charges_minor: int
    discount_minor: int
    recognized_total_minor: int
    paid_minor: int
    pending_minor: int
    refunded_minor: int
    outstanding_minor: int


class ExpenseCreateRequest(BaseModel):
    """Submit a trip or operating expense."""

    model_config = ConfigDict(extra="forbid")

    booking_id: UUID | None = None
    vehicle_id: UUID | None = None
    category: str = Field(..., pattern=r"^(fuel|toll|parking|driver_allowance|maintenance|other)$")
    amount_minor: int = Field(..., gt=0)
    currency: str = Field(default="USD", min_length=3, max_length=3)
    incurred_at: datetime
    description: str = Field(..., min_length=3, max_length=1000)
    receipt_key: str | None = Field(default=None, max_length=255)


class ExpenseDecisionRequest(BaseModel):
    """Approve or reject an expense with review notes."""

    model_config = ConfigDict(extra="forbid")

    status: str = Field(..., pattern=r"^(approved|rejected)$")
    review_notes: str | None = Field(default=None, max_length=1000)


class ExpenseResponse(BaseModel):
    """Serialized trip or operating expense."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    booking_id: UUID | None
    vehicle_id: UUID | None
    driver_id: UUID | None
    submitted_by: UUID
    category: str
    amount_minor: int
    currency: str
    incurred_at: datetime
    description: str
    receipt_key: str | None
    status: str
    reviewed_by: UUID | None
    review_notes: str | None
    reviewed_at: datetime | None
    created_at: datetime


class PeriodFinanceSummary(BaseModel):
    """Company-wide cash flow vs recognized revenue and expense reconciliation."""

    currency: str
    recognized_revenue_minor: int
    cash_collected_minor: int
    pending_collections_minor: int
    refunded_minor: int
    approved_expenses_minor: int
    net_cash_flow_minor: int
