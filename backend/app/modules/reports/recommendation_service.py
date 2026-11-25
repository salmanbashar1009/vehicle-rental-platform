"""Dispatch recommendation scoring engine for eligible vehicles and drivers."""

from typing import cast
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NotFoundError
from app.modules.bookings.models import Booking
from app.modules.dispatch.eligibility_service import DispatchEligibilityService
from app.modules.dispatch.models import Assignment
from app.modules.reports.schemas import (
    DispatchRecommendationItem,
    DispatchRecommendationsResponse,
)
from app.modules.reviews.models import Review
from app.modules.trips.models import Trip
from app.modules.vehicles.models import Vehicle


class DispatchRecommendationService:
    """Scores eligible vehicles and drivers for fast informed dispatcher selection."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def recommend_for_booking(self, booking_id: UUID) -> DispatchRecommendationsResponse:
        """Rank eligible vehicles by capacity fit & preference and drivers by rating/trips."""
        booking = (
            await self._session.execute(
                select(Booking).where(Booking.id == booking_id, Booking.deleted_at.is_(None))
            )
        ).scalar_one_or_none()
        if booking is None:
            raise NotFoundError("Booking not found.")

        elig = await DispatchEligibilityService(self._session).get_eligible_resources(booking_id)

        veh_scores: list[DispatchRecommendationItem] = []
        for v in elig.vehicles:
            if not v.is_eligible:
                continue
            score = 70
            reason = "Eligible"
            if booking.preferred_vehicle_id == v.id:
                score += 25
                reason = "Customer preferred vehicle"
            elif v.seat_capacity >= booking.passenger_count:
                slack = v.seat_capacity - booking.passenger_count
                score += max(0, 15 - slack)
                if reason == "Eligible":
                    reason = "Optimal seat capacity fit"
            veh_obj = (
                await self._session.execute(select(Vehicle).where(Vehicle.id == v.id))
            ).scalar_one_or_none()
            if veh_obj and veh_obj.status == "available":
                score += 5
            veh_scores.append(
                DispatchRecommendationItem(
                    id=v.id, label=f"{v.plate_number} - {v.name}", score=score, reason=reason
                )
            )
        veh_scores.sort(key=lambda x: x.score, reverse=True)

        drv_scores: list[DispatchRecommendationItem] = []
        for d in elig.drivers:
            if not d.is_eligible:
                continue
            trips_done = int(
                (
                    await self._session.execute(
                        select(func.count(Trip.id))
                        .join(Assignment, Trip.assignment_id == Assignment.id)
                        .where(Assignment.driver_id == d.id, Trip.status == "service_completed")
                    )
                ).scalar_one()
                or 0
            )
            avg_rating = cast(
                float | None,
                (
                    await self._session.execute(
                        select(func.avg(Review.driver_rating)).where(
                            Review.driver_id == d.id, Review.moderation_status == "published"
                        )
                    )
                ).scalar_one(),
            )
            score = (
                75
                + min(15, trips_done * 3)
                + (int(round(float(avg_rating) * 2)) if avg_rating else 5)
            )
            rating_txt = f"{float(avg_rating):.1f} stars" if avg_rating else "New/Unrated"
            drv_scores.append(
                DispatchRecommendationItem(
                    id=d.id,
                    label=d.full_name,
                    score=score,
                    reason=f"{trips_done} completed trips • {rating_txt}",
                )
            )
        drv_scores.sort(key=lambda x: x.score, reverse=True)

        return DispatchRecommendationsResponse(
            booking_id=booking_id, vehicles=veh_scores, drivers=drv_scores
        )
