"""FastAPI router for post-trip customer reviews and moderation."""

from uuid import UUID

from fastapi import APIRouter, Depends, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.session import get_db_session
from app.modules.authentication.dependencies import (
    CurrentActor,
    require_permissions,
    require_roles,
)
from app.modules.reviews.schemas import ReviewCreateRequest, ReviewModerateRequest, ReviewResponse
from app.modules.reviews.service import ReviewService

router = APIRouter(prefix="/reviews", tags=["Reviews & Ratings"])


@router.post("", response_model=ReviewResponse, status_code=status.HTTP_201_CREATED)
async def submit_booking_review(
    payload: ReviewCreateRequest,
    actor: CurrentActor = Depends(require_roles("customer")),
    session: AsyncSession = Depends(get_db_session),
) -> ReviewResponse:
    """Customer submits rating for own completed booking."""
    return await ReviewService(session).submit_review(payload, actor=actor)


@router.get("", response_model=list[ReviewResponse])
async def list_reviews(
    _actor: CurrentActor = Depends(require_permissions("bookings.read")),
    session: AsyncSession = Depends(get_db_session),
) -> list[ReviewResponse]:
    """List all reviews for admin moderation."""
    return await ReviewService(session).list_reviews()


@router.patch("/{review_id}/moderate", response_model=ReviewResponse)
async def moderate_review(
    review_id: UUID,
    payload: ReviewModerateRequest,
    request: Request,
    actor: CurrentActor = Depends(require_permissions("bookings.write")),
    session: AsyncSession = Depends(get_db_session),
) -> ReviewResponse:
    """Publish or hide a customer review."""
    return await ReviewService(session).moderate_review(
        review_id,
        payload,
        actor=actor,
        correlation_id=getattr(request.state, "correlation_id", None),
    )
