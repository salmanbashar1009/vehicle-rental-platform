"""Notification schemas and service."""

from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NotFoundError
from app.modules.notifications.models import Notification, NotificationOutbox


class NotificationResponse(BaseModel):
    """Serialized in-app notification response."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    event_type: str
    title: str
    body: str
    priority: str
    resource_type: str | None
    resource_id: str | None
    is_read: bool
    created_at: datetime


class NotificationService:
    """Stages in-app notifications and outbox jobs inside caller transactions."""

    @staticmethod
    async def enqueue(
        session: AsyncSession,
        *,
        user_id: UUID | None,
        event_type: str,
        title: str,
        body: str,
        dedup_key: str,
        priority: str = "normal",
        channels: tuple[str, ...] = ("in_app", "push"),
        resource_type: str | None = None,
        resource_id: str | None = None,
        extra_payload: dict[str, Any] | None = None,
    ) -> None:
        """Create in-app notification and deduplicated outbox items."""
        existing = (
            await session.execute(
                select(NotificationOutbox).where(NotificationOutbox.dedup_key == dedup_key)
            )
        ).scalar_one_or_none()
        if existing is not None:
            return

        if user_id is not None and "in_app" in channels:
            session.add(
                Notification(
                    user_id=user_id,
                    event_type=event_type,
                    title=title,
                    body=body,
                    priority=priority,
                    resource_type=resource_type,
                    resource_id=resource_id,
                )
            )

        for idx, channel in enumerate(ch for ch in channels if ch != "in_app"):
            session.add(
                NotificationOutbox(
                    dedup_key=f"{dedup_key}:{channel}:{idx}",
                    recipient_user_id=user_id,
                    channel=channel,
                    event_type=event_type,
                    payload_json={
                        "title": title,
                        "body": body,
                        "priority": priority,
                        **(extra_payload or {}),
                    },
                )
            )

    @staticmethod
    async def list_for_user(
        session: AsyncSession, *, user_id: UUID, limit: int = 50
    ) -> list[NotificationResponse]:
        """List recent notifications owned by user_id."""
        stmt = (
            select(Notification)
            .where(Notification.user_id == user_id)
            .order_by(Notification.created_at.desc())
            .limit(limit)
        )
        rows = (await session.execute(stmt)).scalars().all()
        return [NotificationResponse.model_validate(r) for r in rows]

    @staticmethod
    async def mark_read(
        session: AsyncSession, *, notification_id: UUID, user_id: UUID
    ) -> NotificationResponse:
        """Mark notification read only if owned by user_id."""
        stmt = select(Notification).where(
            Notification.id == notification_id, Notification.user_id == user_id
        )
        row = (await session.execute(stmt)).scalar_one_or_none()
        if row is None:
            raise NotFoundError("Notification not found.")
        row.is_read = True
        await session.commit()
        await session.refresh(row)
        return NotificationResponse.model_validate(row)
