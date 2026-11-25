"""Unit tests for Phase 1 Pydantic contracts, idempotency hashing, and RBAC definitions."""

from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
from pydantic import ValidationError

from app.core.exceptions import ValidationDomainError
from app.core.idempotency import compute_request_hash, parse_idempotency_key
from app.core.money import Money
from app.modules.authentication.dependencies import CurrentActor
from app.modules.bookings.schemas import BookingCreateRequest
from app.modules.services.seed import DEFAULT_SERVICES
from app.modules.users.seed import ROLE_MATRIX


def test_booking_create_schema_forbids_extra_and_invalid_window() -> None:
    """Reject unknown client fields (e.g., price spoofing) and inverted schedules."""
    now = datetime.now(UTC)
    with pytest.raises(ValidationError):
        BookingCreateRequest.model_validate(
            {
                "service_slug": "tour_travel",
                "pickup_at": now.isoformat(),
                "expected_end_at": (now + timedelta(hours=2)).isoformat(),
                "stops": [
                    {"stop_type": "pickup", "address": "Start"},
                    {"stop_type": "destination", "address": "End"},
                ],
                "total_minor": 1,  # spoofed extra field must be rejected
            }
        )

    with pytest.raises(ValidationError):
        BookingCreateRequest.model_validate(
            {
                "service_slug": "tour_travel",
                "pickup_at": (now + timedelta(hours=3)).isoformat(),
                "expected_end_at": now.isoformat(),
                "stops": [
                    {"stop_type": "pickup", "address": "Start"},
                    {"stop_type": "destination", "address": "End"},
                ],
            }
        )


def test_idempotency_hash_and_uuid_validation() -> None:
    """Verify deterministic request hashing and UUID Idempotency-Key parsing."""
    h1 = compute_request_hash({"a": 1, "b": 2})
    h2 = compute_request_hash({"b": 2, "a": 1})
    assert h1 == h2
    valid = parse_idempotency_key("11111111-1111-4111-8111-111111111111")
    assert valid == "11111111-1111-4111-8111-111111111111"
    with pytest.raises(ValidationDomainError):
        parse_idempotency_key("not-a-uuid")


def test_eight_roles_and_eight_services_configured() -> None:
    """Ensure all 8 RBAC roles and 8 transport services are defined."""
    assert len(ROLE_MATRIX) == 8
    assert len(DEFAULT_SERVICES) == 8
    actor = CurrentActor(
        user_id=uuid4(),
        session_id=uuid4(),
        roles=frozenset({"dispatcher"}),
        permissions=frozenset({"dispatch.write"}),
        full_name="Disp",
        email="d@example.com",
        phone=None,
    )
    assert actor.has_permission("dispatch.write") is True
    assert actor.has_permission("finance.write") is False


def test_money_schema_rejects_invalid_currency() -> None:
    """Currency must be 3 uppercase ISO-4217 letters."""
    m = Money(amount_minor=5000, currency="USD")
    assert m.amount_minor == 5000
    with pytest.raises(ValidationError):
        Money(amount_minor=5000, currency="usd")
