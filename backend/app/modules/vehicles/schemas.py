"""Pydantic schemas for vehicles, documents, and availability calendars."""

from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

VEHICLE_STATUSES = (
    "available",
    "reserved",
    "assigned",
    "en_route",
    "in_service",
    "returning",
    "maintenance",
    "out_of_service",
)


class VehicleImageResponse(BaseModel):
    """Public vehicle image descriptor."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    object_key: str
    is_primary: bool
    sort_order: int


class VehicleDocumentResponse(BaseModel):
    """Vehicle document expiry metadata (admin only)."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    doc_type: str
    doc_number: str
    expires_at: date


class VehicleCreateRequest(BaseModel):
    """Create vehicle payload."""

    model_config = ConfigDict(extra="forbid")

    plate_number: str = Field(..., min_length=2, max_length=32)
    name: str = Field(..., min_length=2, max_length=160)
    category: str = Field(..., min_length=2, max_length=64)
    make: str = Field(..., min_length=1, max_length=80)
    model: str = Field(..., min_length=1, max_length=80)
    year: int = Field(..., ge=1980, le=2100)
    seat_capacity: int = Field(..., ge=1, le=100)
    luggage_capacity: int = Field(default=0, ge=0, le=200)
    cargo_volume_m3: float | None = Field(default=None, ge=0)
    fuel_type: str = Field(..., min_length=2, max_length=32)
    facilities_json: list[str] = Field(default_factory=list)
    indicative_daily_rate_minor: int | None = Field(default=None, ge=0)
    currency: str = Field(default="USD", min_length=3, max_length=3)
    odometer_km: int = Field(default=0, ge=0)
    is_public: bool = True
    description: str | None = Field(default=None, max_length=2000)


class VehicleUpdateRequest(BaseModel):
    """Partial vehicle update payload."""

    model_config = ConfigDict(extra="forbid")

    name: str | None = Field(default=None, min_length=2, max_length=160)
    category: str | None = Field(default=None, min_length=2, max_length=64)
    seat_capacity: int | None = Field(default=None, ge=1, le=100)
    luggage_capacity: int | None = Field(default=None, ge=0, le=200)
    facilities_json: list[str] | None = None
    indicative_daily_rate_minor: int | None = Field(default=None, ge=0)
    status: str | None = None
    odometer_km: int | None = Field(default=None, ge=0)
    is_public: bool | None = None
    description: str | None = Field(default=None, max_length=2000)


class VehicleResponse(BaseModel):
    """Vehicle response for catalogue and admin views."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    plate_number: str
    name: str
    category: str
    make: str
    model: str
    year: int
    seat_capacity: int
    luggage_capacity: int
    fuel_type: str
    facilities_json: list[str]
    indicative_daily_rate_minor: int | None
    currency: str
    status: str
    odometer_km: int
    is_public: bool
    description: str | None
    images: list[VehicleImageResponse]
    is_available_for_window: bool | None = None


class ScheduleBlockResponse(BaseModel):
    """Schedule block entry for availability calendar."""

    id: UUID
    block_type: str
    source_id: UUID
    start_at: datetime
    end_at: datetime
