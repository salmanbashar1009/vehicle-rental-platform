"""Trip milestone progression service."""

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, ValidationDomainError
from app.modules.audit.service import AuditService
from app.modules.authentication.dependencies import CurrentActor
from app.modules.bookings.models import BookingStatusHistory
from app.modules.trips.models import TripStatusEvent
from app.modules.trips.schemas import MilestoneTransitionRequest, TripResponse
from app.modules.trips.trip_helpers import load_owned_trip, release_booking_locks


class TripExecutionService:
    """Enforces configurable milestone workflows with strict sequential progression."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def transition_milestone(
        self,
        trip_id: UUID,
        payload: MilestoneTransitionRequest,
        *,
        actor: CurrentActor,
        idempotency_key: str,
        correlation_id: str | None,
    ) -> TripResponse:
        """Advance trip milestone strictly according to service_workflows."""
        existing_evt = (
            await self._session.execute(
                select(TripStatusEvent).where(TripStatusEvent.idempotency_key == idempotency_key)
            )
        ).scalar_one_or_none()
        trip, assignment, driver, booking, steps = await load_owned_trip(
            self._session, trip_id, actor, for_update=True
        )
        if existing_evt is not None:
            if existing_evt.trip_id != trip.id or existing_evt.milestone != payload.milestone:
                raise ConflictError("Idempotency-Key conflict on milestone transition.")
            return TripResponse.model_validate(trip)

        target = payload.milestone
        if target != "cancelled_or_exception":
            if target not in steps:
                raise ValidationDomainError(f"Milestone '{target}' is invalid for this service.")
            if trip.status not in steps:
                raise ValidationDomainError(f"Trip in '{trip.status}' cannot advance.")
            cur_idx = steps.index(trip.status)
            tgt_idx = steps.index(target)
            if tgt_idx != cur_idx + 1:
                next_step = steps[cur_idx + 1] if cur_idx + 1 < len(steps) else "none"
                raise ValidationDomainError(
                    f"Must progress sequentially from '{trip.status}' (expected '{next_step}')."
                )

        prev = trip.status
        trip.status = target
        if target == "en_route_to_pickup" and trip.started_at is None:
            trip.started_at = payload.occurred_at
            assignment.status = "active"
            driver.availability_status = "on_duty"
            if booking.status != "in_progress":
                prev_b = booking.status
                booking.status = "in_progress"
                self._session.add(
                    BookingStatusHistory(
                        booking_id=booking.id,
                        from_status=prev_b,
                        to_status="in_progress",
                        changed_by=actor.user_id,
                        reason="Driver started trip",
                    )
                )

        if target == "cancelled_or_exception":
            booking.status = "exception"
            await release_booking_locks(self._session, booking.id)

        self._session.add(
            TripStatusEvent(
                trip_id=trip.id,
                milestone=target,
                occurred_at=payload.occurred_at,
                lat=payload.lat,
                lng=payload.lng,
                notes=payload.notes,
                idempotency_key=idempotency_key,
            )
        )
        AuditService.record(
            self._session,
            actor_id=actor.user_id,
            actor_role="driver",
            action=f"trip.milestone.{target}",
            resource_type="trip",
            resource_id=str(trip.id),
            before_state={"status": prev},
            after_state={"status": target},
            correlation_id=correlation_id,
        )
        await self._session.commit()
        await self._session.refresh(trip)
        return TripResponse.model_validate(trip)
