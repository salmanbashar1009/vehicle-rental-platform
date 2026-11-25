"""Pydantic schemas for bookings, stops, and quotations."""

from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field, model_validator


class BookingStopInput(BaseModel):
    """Pickup, waypoint, or destination stop."""

    model_config = ConfigDict(extra="forbid")

    stop_type: str = Field(..., pattern=r"^(pickup|waypoint|destination)$")
    address: str = Field(..., min_length=2, max_length=500)
    lat: float | None = Field(default=None, ge=-90.0, le=90.0)
    lng: float | None = Field(default=None, ge=-180.0, le=180.0)


class BookingCreateRequest(BaseModel):
    """Create booking / quote request payload."""

    model_config = ConfigDict(extra="forbid")

    service_slug: str = Field(..., min_length=2, max_length=64)
    preferred_vehicle_id: UUID | None = None
    pickup_at: datetime
    expected_end_at: datetime
    passenger_count: int = Field(default=1, ge=1, le=200)
    luggage_count: int = Field(default=0, ge=0, le=500)
    cargo_details_json: dict[str, Any] | None = None
    service_metadata_json: dict[str, Any] = Field(default_factory=dict)
    special_instructions: str | None = Field(default=None, max_length=2000)
    stops: list[BookingStopInput] = Field(..., min_length=2, max_length=20)

    customer_name: str | None = Field(default=None, min_length=2, max_length=160)
    customer_email: EmailStr | None = None
    customer_phone: str | None = Field(default=None, min_length=6, max_length=32)

    @model_validator(mode="after")
    def _validate_window(self) -> "BookingCreateRequest":
        if self.expected_end_at <= self.pickup_at:
            raise ValueError("expected_end_at must be after pickup_at")
        return self


class BookingActionRequest(BaseModel):
    """Confirm, reject, cancel, or add notes payload."""

    model_config = ConfigDict(extra="forbid")

    vehicle_id: UUID | None = None
    reason: str | None = Field(default=None, max_length=1000)
    internal_notes: str | None = Field(default=None, max_length=2000)


class BookingRescheduleRequest(BaseModel):
    """Reschedule booking window payload."""

    model_config = ConfigDict(extra="forbid")

    pickup_at: datetime
    expected_end_at: datetime
    reason: str = Field(..., min_length=3, max_length=500)


class QuotationLineItem(BaseModel):
    """Single itemized charge in a quotation."""

    model_config = ConfigDict(extra="forbid")

    label: str = Field(..., min_length=1, max_length=160)
    quantity: int = Field(default=1, ge=1)
    unit_amount_minor: int = Field(..., ge=0)


class QuotationCreateRequest(BaseModel):
    """Create and send an itemized quotation."""

    model_config = ConfigDict(extra="forbid")

    items: list[QuotationLineItem] = Field(..., min_length=1)
    discount_minor: int = Field(default=0, ge=0)
    tax_minor: int = Field(default=0, ge=0)
    deposit_minor: int = Field(default=0, ge=0)
    currency: str = Field(default="USD", min_length=3, max_length=3)
    valid_until: datetime
    terms: str | None = Field(default=None, max_length=2000)


class BookingStopResponse(BaseModel):
    """Serialized stop response."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    seq_order: int
    stop_type: str
    address: str
    lat: float | None
    lng: float | None


class BookingStatusHistoryResponse(BaseModel):
    """Serialized status change timeline item."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    from_status: str | None
    to_status: str
    reason: str | None
    created_at: datetime


class QuotationResponse(BaseModel):
    """Serialized quotation response."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    booking_id: UUID
    version: int
    items_json: list[dict[str, Any]]
    subtotal_minor: int
    discount_minor: int
    tax_minor: int
    total_minor: int
    deposit_minor: int
    currency: str
    valid_until: datetime
    terms: str | None
    status: str
    responded_at: datetime | None
    created_at: datetime


class BookingResponse(BaseModel):
    """Serialized booking detail response."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    reference: str
    customer_id: UUID
    service_category_id: UUID
    preferred_vehicle_id: UUID | None
    status: str
    pickup_at: datetime
    expected_end_at: datetime
    passenger_count: int
    luggage_count: int
    cargo_details_json: dict[str, Any] | None
    service_metadata_json: dict[str, Any]
    special_instructions: str | None
    internal_notes: str | None = None
    tracking_enabled: bool
    stops: list[BookingStopResponse]
    status_history: list[BookingStatusHistoryResponse]
    quotations: list[QuotationResponse]
    created_at: datetime
    guest_claim_token: str | None = None
