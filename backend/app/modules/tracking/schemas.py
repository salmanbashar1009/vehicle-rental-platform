"""Pydantic schemas for GPS batch ingestion, live fleet tracking, and playback."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class GpsPointInput(BaseModel):
    """Single timestamped GPS coordinate sample."""

    model_config = ConfigDict(extra="forbid")

    lat: float = Field(..., ge=-90.0, le=90.0)
    lng: float = Field(..., ge=-180.0, le=180.0)
    accuracy_m: float | None = Field(default=None, ge=0.0)
    speed_mps: float | None = Field(default=None, ge=0.0)
    heading_deg: float | None = Field(default=None, ge=0.0, le=360.0)
    recorded_at: datetime


class GpsBatchRequest(BaseModel):
    """Driver app GPS batch upload payload (max 20 points)."""

    model_config = ConfigDict(extra="forbid")

    assignment_id: UUID
    points: list[GpsPointInput] = Field(..., min_length=1, max_length=20)
    interruption_status: str | None = Field(
        default=None, pattern=r"^(gps_disabled|permission_denied|network_offline)$"
    )


class GpsBatchResponse(BaseModel):
    """Result summary for GPS batch ingestion."""

    accepted_count: int
    persisted_count: int
    freshness: str


class VehicleLiveLocationResponse(BaseModel):
    """Live vehicle location and freshness indicator for admin fleet map."""

    vehicle_id: UUID
    vehicle_plate: str
    vehicle_name: str
    driver_id: UUID
    driver_name: str
    booking_id: UUID
    booking_reference: str
    trip_id: UUID
    trip_status: str
    lat: float | None = None
    lng: float | None = None
    accuracy_m: float | None = None
    speed_mps: float | None = None
    heading_deg: float | None = None
    recorded_at: datetime | None = None
    freshness: str


class BookingTrackingResponse(BaseModel):
    """Customer-safe active trip tracking payload (masks private driver PII)."""

    booking_id: UUID
    booking_reference: str
    trip_status: str
    tracking_active: bool
    vehicle_name: str | None = None
    vehicle_plate: str | None = None
    driver_display_name: str | None = None
    lat: float | None = None
    lng: float | None = None
    recorded_at: datetime | None = None
    freshness: str
    stops: list[dict[str, object]] = []


class RoutePointResponse(BaseModel):
    """Historical route breadcrumb for admin trip playback."""

    model_config = ConfigDict(from_attributes=True)

    lat: float
    lng: float
    speed_mps: float | None
    heading_deg: float | None
    recorded_at: datetime
