"""Strict Pydantic v2 schemas for booking reviews and moderation."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class ReviewCreateRequest(BaseModel):
    """Customer post-trip rating payload."""

    model_config = ConfigDict(extra="forbid")

    booking_id: UUID
    overall_rating: int = Field(..., ge=1, le=5)
    driver_rating: int = Field(..., ge=1, le=5)
    vehicle_rating: int = Field(..., ge=1, le=5)
    service_rating: int = Field(..., ge=1, le=5)
    comment: str | None = Field(default=None, max_length=2000)


class ReviewModerateRequest(BaseModel):
    """Admin moderation update (`published` or `hidden`)."""

    model_config = ConfigDict(extra="forbid")

    moderation_status: str = Field(..., pattern=r"^(published|hidden)$")


class ReviewResponse(BaseModel):
    """Serialized customer review."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    booking_id: UUID
    customer_id: UUID
    driver_id: UUID | None
    vehicle_id: UUID | None
    overall_rating: int
    driver_rating: int
    vehicle_rating: int
    service_rating: int
    comment: str | None
    moderation_status: str
    created_at: datetime
