"""Pydantic schemas for users and RBAC roles."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class RoleResponse(BaseModel):
    """Role summary response."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    slug: str
    name: str


class UserCreateRequest(BaseModel):
    """Staff user creation payload."""

    model_config = ConfigDict(extra="forbid")

    email: EmailStr | None = None
    phone: str | None = Field(default=None, min_length=6, max_length=32)
    full_name: str = Field(..., min_length=2, max_length=160)
    password: str = Field(..., min_length=10, max_length=128)
    role_slugs: list[str] = Field(..., min_length=1)


class UserUpdateRequest(BaseModel):
    """Staff user update payload (active status or roles)."""

    model_config = ConfigDict(extra="forbid")

    full_name: str | None = Field(default=None, min_length=2, max_length=160)
    is_active: bool | None = None
    role_slugs: list[str] | None = None
    reason: str | None = Field(default=None, max_length=500)


class UserResponse(BaseModel):
    """Public user representation (never exposes password or MFA secrets)."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    email: str | None
    phone: str | None
    full_name: str
    is_active: bool
    mfa_enabled: bool
    roles: list[RoleResponse]
    created_at: datetime
