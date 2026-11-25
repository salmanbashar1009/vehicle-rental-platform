"""Pydantic schemas for driver assignments, trip milestones, completion, and incidents."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class DeclineAssignmentRequest(BaseModel):
    """Driver inability-to-attend / decline assignment payload."""

    model_config = ConfigDict(extra="forbid")

    reason: str = Field(..., min_length=3, max_length=500)


class DriverAvailabilityUpdateRequest(BaseModel):
    """Driver self-service duty status toggle."""

    model_config = ConfigDict(extra="forbid")

    availability_status: str = Field(..., pattern=r"^(available|on_break|off_duty)$")


class MilestoneTransitionRequest(BaseModel):
    """Trip milestone progression submitted by assigned driver."""

    model_config = ConfigDict(extra="forbid")

    milestone: str = Field(..., min_length=2, max_length=48)
    occurred_at: datetime
    lat: float | None = Field(default=None, ge=-90.0, le=90.0)
    lng: float | None = Field(default=None, ge=-180.0, le=180.0)
    notes: str | None = Field(default=None, max_length=1000)


class TripCompleteRequest(BaseModel):
    """Trip completion payload submitted by driver when service ends."""

    model_config = ConfigDict(extra="forbid")

    completed_at: datetime
    end_odometer: int = Field(..., ge=0)
    actual_distance_km: float | None = Field(default=None, ge=0)
    waiting_minutes: int = Field(default=0, ge=0)
    extra_charges_minor: int = Field(default=0, ge=0)
    currency: str = Field(default="USD", min_length=3, max_length=3)
    completion_notes: str | None = Field(default=None, max_length=2000)
    signature_key: str | None = Field(default=None, max_length=255)


class IncidentCreateRequest(BaseModel):
    """Driver breakdown/emergency/dispute report payload."""

    model_config = ConfigDict(extra="forbid")

    category: str = Field(..., pattern=r"^(breakdown|accident|medical|security|customer_dispute)$")
    severity: str = Field(default="high", pattern=r"^(low|medium|high|critical)$")
    description: str = Field(..., min_length=5, max_length=2000)
    lat: float | None = Field(default=None, ge=-90.0, le=90.0)
    lng: float | None = Field(default=None, ge=-180.0, le=180.0)


class TripStatusEventResponse(BaseModel):
    """Serialized trip milestone event."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    milestone: str
    occurred_at: datetime
    notes: str | None


class TripResponse(BaseModel):
    """Serialized trip record."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    assignment_id: UUID
    status: str
    started_at: datetime | None
    completed_at: datetime | None
    end_odometer: int | None
    waiting_minutes: int
    extra_charges_minor: int
    currency: str
    completion_notes: str | None
    events: list[TripStatusEventResponse]


class DriverAssignmentDetailResponse(BaseModel):
    """Driver-facing view of an assigned booking and trip workflow."""

    assignment_id: UUID
    assignment_status: str
    booking_id: UUID
    booking_reference: str
    service_name: str
    workflow_steps: list[str]
    pickup_at: datetime
    expected_end_at: datetime
    customer_name: str
    customer_phone: str | None
    vehicle_name: str
    vehicle_plate: str
    stops: list[dict[str, object]]
    special_instructions: str | None
    trip: TripResponse | None


class IncidentResponse(BaseModel):
    """Serialized incident report."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    trip_id: UUID
    driver_id: UUID
    category: str
    severity: str
    description: str
    status: str
    created_at: datetime
