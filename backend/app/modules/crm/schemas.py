"""Strict Pydantic v2 schemas for corporate accounts, CRM directory, and comms logs."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class CorporateAccountCreateRequest(BaseModel):
    """Create B2B corporate account with credit limit and negotiated basis-point discount."""

    model_config = ConfigDict(extra="forbid")

    company_name: str = Field(..., min_length=2, max_length=200)
    tax_id: str | None = Field(default=None, max_length=64)
    billing_cycle: str = Field(default="monthly", pattern=r"^(per_trip|weekly|monthly)$")
    credit_limit_minor: int = Field(default=0, ge=0)
    currency: str = Field(default="USD", min_length=3, max_length=3)
    negotiated_discount_bps: int = Field(default=0, ge=0, le=5000)


class CorporateAccountUpdateRequest(BaseModel):
    """Update negotiated corporate account settings."""

    model_config = ConfigDict(extra="forbid")

    billing_cycle: str | None = Field(default=None, pattern=r"^(per_trip|weekly|monthly)$")
    credit_limit_minor: int | None = Field(default=None, ge=0)
    negotiated_discount_bps: int | None = Field(default=None, ge=0, le=5000)
    is_active: bool | None = None


class CorporateAccountResponse(BaseModel):
    """Serialized corporate account with optional computed balance metrics."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    company_name: str
    tax_id: str | None
    billing_cycle: str
    credit_limit_minor: int
    currency: str
    negotiated_discount_bps: int
    is_active: bool


class CorporateBalanceResponse(BaseModel):
    """Outstanding balance and booking metrics for a corporate client."""

    corporate_id: UUID
    company_name: str
    currency: str
    credit_limit_minor: int
    recognized_total_minor: int
    paid_minor: int
    outstanding_minor: int
    active_customers: int
    total_bookings: int


class CustomerLinkCorporateRequest(BaseModel):
    """Assign customer profile to corporate account and update customer type."""

    model_config = ConfigDict(extra="forbid")

    corporate_id: UUID | None = None
    notes: str | None = Field(default=None, max_length=2000)


class CrmCustomerSummary(BaseModel):
    """Customer CRM profile with booking history count and corporate affiliation."""

    id: UUID
    full_name: str
    email: str | None
    phone: str | None
    customer_type: str
    corporate_id: UUID | None
    total_bookings: int
    notes: str | None


class CustomerCommsCreateRequest(BaseModel):
    """Record a staff CRM communication log entry."""

    model_config = ConfigDict(extra="forbid")

    channel: str = Field(..., pattern=r"^(call|email|whatsapp|note)$")
    summary: str = Field(..., min_length=2, max_length=2000)


class CustomerCommsResponse(BaseModel):
    """Serialized customer communication entry."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    customer_id: UUID
    channel: str
    summary: str
    logged_by: UUID
    created_at: datetime
