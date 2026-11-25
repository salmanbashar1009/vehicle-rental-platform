"""Pydantic schemas for driver management."""

from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field

DRIVER_AVAILABILITY_STATUSES = (
    "available",
    "assigned",
    "on_duty",
    "on_break",
    "off_duty",
    "unavailable",
)


class DriverCreateRequest(BaseModel):
    """Create driver account + profile payload."""

    model_config = ConfigDict(extra="forbid")

    full_name: str = Field(..., min_length=2, max_length=160)
    email: EmailStr | None = None
    phone: str = Field(..., min_length=6, max_length=32)
    password: str = Field(..., min_length=10, max_length=128)
    licence_number: str = Field(..., min_length=3, max_length=64)
    licence_classes_json: list[str] = Field(default_factory=list)
    licence_expiry: date
    emergency_contact_name: str | None = Field(default=None, max_length=128)
    emergency_contact_phone: str | None = Field(default=None, max_length=32)


class DriverUpdateRequest(BaseModel):
    """Partial driver profile update payload."""

    model_config = ConfigDict(extra="forbid")

    licence_classes_json: list[str] | None = None
    licence_expiry: date | None = None
    emergency_contact_name: str | None = Field(default=None, max_length=128)
    emergency_contact_phone: str | None = Field(default=None, max_length=32)
    employment_status: str | None = None
    availability_status: str | None = None


class DriverResponse(BaseModel):
    """Driver profile response."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    full_name: str
    email: str | None
    phone: str | None
    licence_number: str
    licence_classes_json: list[str]
    licence_expiry: date
    emergency_contact_name: str | None
    emergency_contact_phone: str | None
    employment_status: str
    availability_status: str
    created_at: datetime
