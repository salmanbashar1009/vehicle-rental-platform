"""Audit logging service (append-only)."""

from typing import Any
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.pagination import PaginatedResponse, PaginationParams
from app.modules.audit.models import AuditLog
from app.modules.audit.schemas import AuditLogResponse


class AuditService:
    """Writes immutable audit records inside the caller's transaction."""

    @staticmethod
    def record(
        session: AsyncSession,
        *,
        actor_id: UUID | None,
        actor_role: str,
        action: str,
        resource_type: str,
        resource_id: str,
        before_state: dict[str, Any] | None = None,
        after_state: dict[str, Any] | None = None,
        reason: str | None = None,
        correlation_id: str | None = None,
        ip_address: str | None = None,
    ) -> AuditLog:
        """Stage a new immutable audit log record in the active session."""
        entry = AuditLog(
            actor_id=actor_id,
            actor_role=actor_role,
            action=action,
            resource_type=resource_type,
            resource_id=resource_id,
            before_state=before_state,
            after_state=after_state,
            reason=reason,
            correlation_id=correlation_id,
            ip_address=ip_address,
        )
        session.add(entry)
        return entry

    @staticmethod
    async def list_logs(
        session: AsyncSession,
        *,
        pagination: PaginationParams,
        resource_type: str | None = None,
        action: str | None = None,
    ) -> PaginatedResponse[AuditLogResponse]:
        """Query audit logs newest-first with optional filters."""
        query = select(AuditLog)
        count_query = select(func.count(AuditLog.id))
        if resource_type:
            query = query.where(AuditLog.resource_type == resource_type)
            count_query = count_query.where(AuditLog.resource_type == resource_type)
        if action:
            query = query.where(AuditLog.action == action)
            count_query = count_query.where(AuditLog.action == action)

        total = int((await session.execute(count_query)).scalar_one())
        rows = (
            (
                await session.execute(
                    query.order_by(AuditLog.created_at.desc())
                    .offset(pagination.offset)
                    .limit(pagination.page_size)
                )
            )
            .scalars()
            .all()
        )
        items = [AuditLogResponse.model_validate(row) for row in rows]
        return PaginatedResponse.create(
            items=items,
            page=pagination.page,
            page_size=pagination.page_size,
            total_items=total,
        )
