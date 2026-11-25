"""Tests for health probes, middleware headers, security utilities, and upload magic bytes."""

import pytest
from httpx import ASGITransport, AsyncClient

from app.core.exceptions import ValidationDomainError
from app.core.money import apply_basis_points
from app.core.security import (
    create_access_token,
    decode_access_token,
    hash_password,
    verify_password,
)
from app.integrations.s3_storage import validate_upload_bytes
from app.main import create_app


def test_argon2_password_hashing_roundtrip() -> None:
    """Verify Argon2id hashes and rejects invalid passwords."""
    hashed = hash_password("Sup3rS3cur3!Pass")
    assert hashed.startswith("$argon2id$")
    assert verify_password("Sup3rS3cur3!Pass", hashed) is True
    assert verify_password("wrong", hashed) is False


def test_jwt_roundtrip() -> None:
    """Verify signed JWT contains expected subject and roles."""
    from uuid import uuid4

    uid, sid = uuid4(), uuid4()
    token = create_access_token(
        user_id=uid, roles=["dispatcher"], permissions=["dispatch.write"], session_id=sid
    )
    decoded = decode_access_token(token)
    assert decoded["sub"] == str(uid)
    assert decoded["roles"] == ["dispatcher"]


def test_money_basis_points_integer_math() -> None:
    """Ensure basis-point math uses deterministic integer rounding."""
    assert apply_basis_points(10000, 1500) == 1500
    assert apply_basis_points(333, 500) == 17


def test_upload_magic_byte_rejects_spoofed_extension() -> None:
    """Reject executable bytes masquerading as a PNG image."""
    with pytest.raises(ValidationDomainError):
        validate_upload_bytes(
            b"MZ\x90\x00spoofed-exe-header",
            filename="evil.png",
            allowed_mimes=frozenset({"image/png", "image/jpeg"}),
        )


def test_upload_magic_byte_accepts_valid_png() -> None:
    """Accept genuine PNG magic bytes."""
    png_bytes = b"\x89PNG\r\n\x1a\n" + b"\x00" * 32
    mime, ext = validate_upload_bytes(
        png_bytes,
        filename="car.png",
        allowed_mimes=frozenset({"image/png", "image/jpeg"}),
    )
    assert mime == "image/png"
    assert ext == ".png"


async def test_health_live_and_security_headers() -> None:
    """Verify /health/live responds 200 with correlation and security headers."""
    app = create_app()
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        res = await ac.get("/health/live")
    assert res.status_code == 200
    assert res.json() == {"status": "ok"}
    assert "X-Correlation-ID" in res.headers
    assert res.headers["X-Content-Type-Options"] == "nosniff"
    assert res.headers["X-Frame-Options"] == "DENY"
