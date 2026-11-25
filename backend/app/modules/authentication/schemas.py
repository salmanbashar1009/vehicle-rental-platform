"""Pydantic schemas for authentication endpoints."""

from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class RegisterRequest(BaseModel):
    """Customer self-registration payload."""

    model_config = ConfigDict(extra="forbid")

    full_name: str = Field(..., min_length=2, max_length=160)
    email: EmailStr | None = None
    phone: str | None = Field(default=None, min_length=6, max_length=32)
    password: str = Field(..., min_length=10, max_length=128)


class LoginRequest(BaseModel):
    """Email or phone login payload."""

    model_config = ConfigDict(extra="forbid")

    identifier: str = Field(..., min_length=3, max_length=255)
    password: str = Field(..., min_length=1, max_length=128)
    totp_code: str | None = Field(default=None, min_length=6, max_length=8)


class RefreshRequest(BaseModel):
    """Refresh token rotation payload."""

    model_config = ConfigDict(extra="forbid")

    refresh_token: str = Field(..., min_length=20, max_length=512)


class PasswordResetRequest(BaseModel):
    """Initiate password recovery flow."""

    model_config = ConfigDict(extra="forbid")

    identifier: str = Field(..., min_length=3, max_length=255)


class PasswordResetConfirmRequest(BaseModel):
    """Complete password reset using single-use token."""

    model_config = ConfigDict(extra="forbid")

    token: str = Field(..., min_length=20, max_length=512)
    new_password: str = Field(..., min_length=10, max_length=128)


class AuthUserSummary(BaseModel):
    """Authenticated user context returned with tokens or /auth/me."""

    id: UUID
    email: str | None
    phone: str | None
    full_name: str
    roles: list[str]
    permissions: list[str]
    mfa_enabled: bool


class TokenPairResponse(BaseModel):
    """JWT access token and rotating refresh token pair."""

    access_token: str
    refresh_token: str
    token_type: str = "bearer"  # noqa: S105
    expires_in: int
    user: AuthUserSummary
