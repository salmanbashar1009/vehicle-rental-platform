"""FastAPI router for user notifications."""

from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.session import get_db_session
from app.modules.authentication.dependencies import CurrentActor, get_current_actor
from app.modules.notifications.service import NotificationResponse, NotificationService

router = APIRouter(prefix="/notifications", tags=["Notifications"])


@router.get("", response_model=list[NotificationResponse])
async def list_my_notifications(
    actor: CurrentActor = Depends(get_current_actor),
    session: AsyncSession = Depends(get_db_session),
) -> list[NotificationResponse]:
    """List current user's recent notifications."""
    return await NotificationService.list_for_user(session, user_id=actor.user_id)


@router.post("/{notification_id}/read", response_model=NotificationResponse)
async def mark_notification_read(
    notification_id: UUID,
    actor: CurrentActor = Depends(get_current_actor),
    session: AsyncSession = Depends(get_db_session),
) -> NotificationResponse:
    """Mark own notification as read."""
    return await NotificationService.mark_read(
        session, notification_id=notification_id, user_id=actor.user_id
    )
