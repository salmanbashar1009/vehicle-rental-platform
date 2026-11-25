"""Cryptographic helpers for Argon2id passwords, JWT access tokens, and opaque tokens."""

import hashlib
import secrets
from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import UUID

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError

from app.core.config import get_settings
from app.core.exceptions import UnauthorizedError

_hasher = PasswordHasher(time_cost=3, memory_cost=65536, parallelism=1)


def hash_password(plain: str) -> str:
    """Hash a plaintext password using Argon2id."""
    return _hasher.hash(plain)


def verify_password(plain: str, hashed: str) -> bool:
    """Verify a plaintext password against an Argon2id hash."""
    try:
        return _hasher.verify(hashed, plain)
    except VerifyMismatchError:
        return False


def needs_rehash(hashed: str) -> bool:
    """Return True if stored hash parameters are weaker than current settings."""
    return _hasher.check_needs_rehash(hashed)


def generate_opaque_token() -> str:
    """Generate a URL-safe cryptographically random token."""
    return secrets.token_urlsafe(48)


def hash_token(raw_token: str) -> str:
    """Return deterministic SHA-256 hex digest for storing opaque tokens safely."""
    return hashlib.sha256(raw_token.encode("utf-8")).hexdigest()


def create_access_token(
    *,
    user_id: UUID,
    roles: list[str],
    permissions: list[str],
    session_id: UUID,
) -> str:
    """Mint a short-lived signed JWT access token."""
    settings = get_settings()
    now = datetime.now(UTC)
    payload: dict[str, Any] = {
        "sub": str(user_id),
        "sid": str(session_id),
        "roles": roles,
        "perms": permissions,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=settings.access_token_expire_minutes)).timestamp()),
        "jti": secrets.token_hex(12),
    }
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def decode_access_token(token: str) -> dict[str, Any]:
    """Decode and validate a JWT access token."""
    settings = get_settings()
    try:
        decoded: dict[str, Any] = jwt.decode(
            token,
            settings.jwt_secret_key,
            algorithms=[settings.jwt_algorithm],
            options={"require": ["sub", "exp", "sid"]},
        )
        return decoded
    except jwt.PyJWTError as exc:
        raise UnauthorizedError("Invalid or expired access token.") from exc
