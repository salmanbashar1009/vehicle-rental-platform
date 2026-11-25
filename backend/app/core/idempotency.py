"""Database-backed idempotency key model and helper."""

import hashlib
import json
from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import UUID, uuid4

from sqlalchemy import JSON, DateTime, Integer, String, UniqueConstraint, select
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Mapped, mapped_column

from app.core.exceptions import ConflictError, ValidationDomainError
from app.database.base import Base


class IdempotencyRecord(Base):
    """Stores idempotent mutation snapshots scoped by actor and key."""

    __tablename__ = "idempotency_keys"
    __table_args__ = (
        UniqueConstraint("actor_scope", "idempotency_key", name="uq_idempotency_actor_key"),
    )

    id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4)
    actor_scope: Mapped[str] = mapped_column(String(128), nullable=False)
    idempotency_key: Mapped[str] = mapped_column(String(128), nullable=False)
    request_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    status_code: Mapped[int] = mapped_column(Integer, nullable=False)
    response_body: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


def compute_request_hash(payload: dict[str, Any]) -> str:
    """Hash canonical JSON payload deterministically."""
    encoded = json.dumps(payload, sort_keys=True, default=str).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def parse_idempotency_key(raw_key: str | None) -> str:
    """Validate required UUID Idempotency-Key header."""
    if not raw_key:
        raise ValidationDomainError("Idempotency-Key header is required.")
    try:
        return str(UUID(raw_key))
    except ValueError as exc:
        raise ValidationDomainError("Idempotency-Key must be a valid UUID.") from exc


async def get_idempotent_replay(
    session: AsyncSession,
    *,
    actor_scope: str,
    idempotency_key: str,
    request_hash: str,
) -> dict[str, Any] | None:
    """Return stored response body if key exists, or raise 409 on payload mismatch."""
    stmt = select(IdempotencyRecord).where(
        IdempotencyRecord.actor_scope == actor_scope,
        IdempotencyRecord.idempotency_key == idempotency_key,
    )
    record = (await session.execute(stmt)).scalar_one_or_none()
    if record is None:
        return None
    if record.request_hash != request_hash:
        raise ConflictError(
            "Idempotency-Key already used with a different request payload.",
            code="IDEMPOTENCY_CONFLICT",
        )
    return record.response_body


async def save_idempotent_response(
    session: AsyncSession,
    *,
    actor_scope: str,
    idempotency_key: str,
    request_hash: str,
    status_code: int,
    response_body: dict[str, Any],
    ttl_hours: int = 24,
) -> None:
    """Persist response snapshot inside current transaction."""
    record = IdempotencyRecord(
        actor_scope=actor_scope,
        idempotency_key=idempotency_key,
        request_hash=request_hash,
        status_code=status_code,
        response_body=response_body,
        expires_at=datetime.now(UTC) + timedelta(hours=ttl_hours),
    )
    session.add(record)
