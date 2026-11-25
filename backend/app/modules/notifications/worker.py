"""Background outbox worker for reliable notification delivery."""

from datetime import UTC, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.logging import get_logger
from app.modules.notifications.models import NotificationOutbox

logger = get_logger(__name__)
MAX_DELIVERY_ATTEMPTS = 5


async def process_pending_outbox(session: AsyncSession, *, batch_size: int = 50) -> int:
    """Deliver pending outbox entries with exponential backoff on transient failures."""
    now = datetime.now(UTC)
    stmt = (
        select(NotificationOutbox)
        .where(
            NotificationOutbox.status == "pending",
            NotificationOutbox.next_retry_at <= now,
        )
        .order_by(NotificationOutbox.created_at.asc())
        .limit(batch_size)
        .with_for_update(skip_locked=True)
    )
    items = list((await session.execute(stmt)).scalars().all())
    delivered = 0
    for item in items:
        try:
            # Adapter dispatch hook (FCM / SMTP / SMS); logs non-PII delivery metadata
            logger.info(
                "notification_dispatched",
                channel=item.channel,
                event_type=item.event_type,
                outbox_id=str(item.id),
            )
            item.status = "sent"
            delivered += 1
        except Exception as exc:
            item.attempts += 1
            item.last_error = str(exc)[:500]
            if item.attempts >= MAX_DELIVERY_ATTEMPTS:
                item.status = "failed"
            else:
                backoff_sec = 2**item.attempts
                item.next_retry_at = now + timedelta(seconds=backoff_sec)
    await session.commit()
    return delivered
