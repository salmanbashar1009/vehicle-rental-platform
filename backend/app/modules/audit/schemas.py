"""Audit log Pydantic response schema."""

from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class AuditLogResponse(BaseModel):
    """Public audit log entry response."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    actor_id: UUID | None
    actor_role: str
    action: str
    resource_type: str
    resource_id: str
    before_state: dict[str, Any] | None
    after_state: dict[str, Any] | None
    reason: str | None
    correlation_id: str | None
    ip_address: str | None
    created_at: datetime
