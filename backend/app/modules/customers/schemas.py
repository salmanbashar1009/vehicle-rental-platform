"""Pydantic schemas for customer profiles."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class CustomerProfileUpdateRequest(BaseModel):
    """Customer self-profile update payload."""

    model_config = ConfigDict(extra="forbid")

    full_name: str | None = Field(default=None, min_length=2, max_length=160)
    email: EmailStr | None = None
    phone: str | None = Field(default=None, min_length=6, max_length=32)


class CustomerProfileResponse(BaseModel):
    """Customer profile response."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID | None
    corporate_id: UUID | None
    customer_type: str
    full_name: str
    email: str | None
    phone: str | None
    created_at: datetime
