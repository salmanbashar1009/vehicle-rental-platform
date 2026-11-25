"""Customer review submission and admin moderation service."""

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError, ValidationDomainError
from app.modules.audit.service import AuditService
from app.modules.authentication.dependencies import CurrentActor
from app.modules.bookings.models import Booking
from app.modules.customers.models import CustomerProfile
from app.modules.dispatch.models import Assignment
from app.modules.reviews.models import Review
from app.modules.reviews.schemas import (
    ReviewCreateRequest,
    ReviewModerateRequest,
    ReviewResponse,
)


class ReviewService:
    """Enforces once-per-completed-booking review rules and moderation."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def submit_review(
        self, payload: ReviewCreateRequest, *, actor: CurrentActor
    ) -> ReviewResponse:
        """Allow owning customer to review a completed/closed booking exactly once."""
        profile = (
            await self._session.execute(
                select(CustomerProfile).where(CustomerProfile.user_id == actor.user_id)
            )
        ).scalar_one_or_none()
        booking = (
            await self._session.execute(
                select(Booking).where(
                    Booking.id == payload.booking_id, Booking.deleted_at.is_(None)
                )
            )
        ).scalar_one_or_none()
        if booking is None:
            raise NotFoundError("Booking not found.")
        if profile is None or booking.customer_id != profile.id:
            raise ForbiddenError("You can only review your own completed bookings.")
        if booking.status not in ("completed", "closed"):
            raise ValidationDomainError("Reviews are only permitted after trip completion.")

        existing = (
            await self._session.execute(select(Review).where(Review.booking_id == booking.id))
        ).scalar_one_or_none()
        if existing is not None:
            raise ConflictError("Review already submitted for this booking.")

        assign = (
            await self._session.execute(
                select(Assignment).where(
                    Assignment.booking_id == booking.id, Assignment.is_current.is_(True)
                )
            )
        ).scalar_one_or_none()
        rev = Review(
            booking_id=booking.id,
            customer_id=profile.id,
            driver_id=assign.driver_id if assign else None,
            vehicle_id=assign.vehicle_id if assign else None,
            overall_rating=payload.overall_rating,
            driver_rating=payload.driver_rating,
            vehicle_rating=payload.vehicle_rating,
            service_rating=payload.service_rating,
            comment=payload.comment,
        )
        self._session.add(rev)
        await self._session.commit()
        await self._session.refresh(rev)
        return ReviewResponse.model_validate(rev)

    async def list_reviews(self, *, published_only: bool = False) -> list[ReviewResponse]:
        """List reviews for admin moderation or public published view."""
        stmt = select(Review).order_by(Review.created_at.desc())
        if published_only:
            stmt = stmt.where(Review.moderation_status == "published")
        rows = (await self._session.execute(stmt)).scalars().all()
        return [ReviewResponse.model_validate(r) for r in rows]

    async def moderate_review(
        self,
        review_id: UUID,
        payload: ReviewModerateRequest,
        *,
        actor: CurrentActor,
        correlation_id: str | None,
    ) -> ReviewResponse:
        """Toggle review moderation status (`published` | `hidden`) with audit record."""
        rev = (
            await self._session.execute(select(Review).where(Review.id == review_id))
        ).scalar_one_or_none()
        if rev is None:
            raise NotFoundError("Review not found.")
        prev = rev.moderation_status
        rev.moderation_status = payload.moderation_status
        rev.moderated_by = actor.user_id
        AuditService.record(
            self._session,
            actor_id=actor.user_id,
            actor_role=actor.primary_role,
            action="review.moderated",
            resource_type="review",
            resource_id=str(rev.id),
            before_state={"moderation_status": prev},
            after_state={"moderation_status": rev.moderation_status},
            correlation_id=correlation_id,
        )
        await self._session.commit()
        await self._session.refresh(rev)
        return ReviewResponse.model_validate(rev)
