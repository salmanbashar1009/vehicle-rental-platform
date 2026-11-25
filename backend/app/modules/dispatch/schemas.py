"""Pydantic schemas for dispatch and resource eligibility."""

from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class DispatchAssignRequest(BaseModel):
    """Assign or reassign vehicle and driver to a booking."""

    model_config = ConfigDict(extra="forbid")

    booking_id: UUID
    vehicle_id: UUID
    driver_id: UUID
    reason: str | None = Field(default=None, max_length=500)


class AssignmentResponse(BaseModel):
    """Assignment record response."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    booking_id: UUID
    vehicle_id: UUID
    driver_id: UUID
    status: str
    assigned_by: UUID | None
    acknowledged_at: datetime | None
    is_current: bool
    created_at: datetime


class EligibleVehicleItem(BaseModel):
    """Vehicle candidate annotated with availability/conflict reason."""

    id: UUID
    plate_number: str
    name: str
    category: str
    seat_capacity: int
    status: str
    is_eligible: bool
    conflict_reason: str | None = None


class EligibleDriverItem(BaseModel):
    """Driver candidate annotated with availability/licence eligibility."""

    id: UUID
    full_name: str
    phone: str | None
    licence_number: str
    licence_expiry: date
    availability_status: str
    is_eligible: bool
    conflict_reason: str | None = None


class EligibleResourcesResponse(BaseModel):
    """Combined eligible vehicles and drivers for a target booking."""

    booking_id: UUID
    pickup_at: datetime
    expected_end_at: datetime
    vehicles: list[EligibleVehicleItem]
    drivers: list[EligibleDriverItem]
