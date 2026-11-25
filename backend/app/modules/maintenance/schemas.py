"""Strict Pydantic v2 schemas for vehicle maintenance and expiry scanning."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator


class MaintenanceCreateRequest(BaseModel):
    """Create preventive/repair maintenance schedule with automatic vehicle block."""

    model_config = ConfigDict(extra="forbid")

    vehicle_id: UUID
    maint_type: str = Field(
        ..., pattern=r"^(preventive|repair|tyre|battery|oil_change|inspection)$"
    )
    description: str = Field(..., min_length=3, max_length=1500)
    provider_name: str | None = Field(default=None, max_length=160)
    scheduled_start: datetime
    scheduled_end: datetime
    cost_minor: int = Field(default=0, ge=0)
    currency: str = Field(default="USD", min_length=3, max_length=3)
    odometer_km: int | None = Field(default=None, ge=0)
    receipt_key: str | None = Field(default=None, max_length=255)

    @model_validator(mode="after")
    def _validate_window(self) -> "MaintenanceCreateRequest":
        if self.scheduled_end <= self.scheduled_start:
            raise ValueError("scheduled_end must be after scheduled_start")
        return self


class MaintenanceStatusUpdateRequest(BaseModel):
    """Transition maintenance status (`in_progress`, `completed`, `cancelled`)."""

    model_config = ConfigDict(extra="forbid")

    status: str = Field(..., pattern=r"^(scheduled|in_progress|completed|cancelled)$")
    cost_minor: int | None = Field(default=None, ge=0)
    odometer_km: int | None = Field(default=None, ge=0)
    receipt_key: str | None = Field(default=None, max_length=255)


class MaintenanceResponse(BaseModel):
    """Serialized maintenance record."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    vehicle_id: UUID
    maint_type: str
    description: str
    provider_name: str | None
    scheduled_start: datetime
    scheduled_end: datetime
    cost_minor: int
    currency: str
    odometer_km: int | None
    receipt_key: str | None
    status: str
    created_at: datetime


class ExpiryScanResponse(BaseModel):
    """Summary of document and driver licence expiry alerts emitted."""

    doc_alerts_created: int
    licence_alerts_created: int
