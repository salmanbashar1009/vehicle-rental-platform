"""Trip completion and urgent incident reporting services."""

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ValidationDomainError
from app.modules.audit.service import AuditService
from app.modules.authentication.dependencies import CurrentActor
from app.modules.bookings.models import BookingStatusHistory
from app.modules.notifications.service import NotificationService
from app.modules.trips.models import IncidentReport
from app.modules.trips.schemas import (
    IncidentCreateRequest,
    IncidentResponse,
    TripCompleteRequest,
    TripResponse,
)
from app.modules.trips.trip_helpers import load_owned_trip, release_booking_locks
from app.modules.vehicles.models import Vehicle


class TripCompletionService:
    """Finalizes trip completion and logs driver incident reports."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def complete_trip(
        self,
        trip_id: UUID,
        payload: TripCompleteRequest,
        *,
        actor: CurrentActor,
        correlation_id: str | None,
    ) -> TripResponse:
        """Finalize trip completion details, update vehicle odometer, and close GPS window."""
        trip, assignment, driver, booking, _ = await load_owned_trip(
            self._session, trip_id, actor, for_update=True
        )
        if trip.status == "cancelled_or_exception":
            raise ValidationDomainError("Cannot complete a cancelled/exception trip.")

        trip.status = "service_completed"
        trip.completed_at = payload.completed_at
        trip.end_odometer = payload.end_odometer
        trip.actual_distance_km = payload.actual_distance_km
        trip.waiting_minutes = payload.waiting_minutes
        trip.extra_charges_minor = payload.extra_charges_minor
        trip.currency = payload.currency.upper()
        trip.completion_notes = payload.completion_notes
        trip.signature_key = payload.signature_key

        assignment.status = "completed"
        driver.availability_status = "available"
        prev_b = booking.status
        booking.status = "completed"
        self._session.add(
            BookingStatusHistory(
                booking_id=booking.id,
                from_status=prev_b,
                to_status="completed",
                changed_by=actor.user_id,
                reason="Service completed by driver",
            )
        )

        vehicle = (
            await self._session.execute(select(Vehicle).where(Vehicle.id == assignment.vehicle_id))
        ).scalar_one()
        if payload.end_odometer > vehicle.odometer_km:
            vehicle.odometer_km = payload.end_odometer
        vehicle.status = "available"
        await release_booking_locks(self._session, booking.id)

        AuditService.record(
            self._session,
            actor_id=actor.user_id,
            actor_role="driver",
            action="trip.completed",
            resource_type="trip",
            resource_id=str(trip.id),
            after_state={"end_odometer": payload.end_odometer},
            correlation_id=correlation_id,
        )
        await self._session.commit()
        await self._session.refresh(trip)
        return TripResponse.model_validate(trip)

    async def report_incident(
        self,
        trip_id: UUID,
        payload: IncidentCreateRequest,
        *,
        actor: CurrentActor,
        correlation_id: str | None,
    ) -> IncidentResponse:
        """Record urgent breakdown/accident/emergency and notify operations."""
        trip, assignment, driver, booking, _ = await load_owned_trip(self._session, trip_id, actor)
        incident = IncidentReport(
            trip_id=trip.id,
            driver_id=driver.id,
            category=payload.category,
            severity=payload.severity,
            description=payload.description,
            lat=payload.lat,
            lng=payload.lng,
        )
        self._session.add(incident)
        await self._session.flush()
        await NotificationService.enqueue(
            self._session,
            user_id=assignment.assigned_by,
            event_type="incident.urgent",
            title=f"URGENT {payload.category.upper()} — {booking.reference}",
            body=payload.description,
            dedup_key=f"incident:{incident.id}",
            priority="critical",
            resource_type="incident",
            resource_id=str(incident.id),
        )
        AuditService.record(
            self._session,
            actor_id=actor.user_id,
            actor_role="driver",
            action="trip.incident_reported",
            resource_type="incident",
            resource_id=str(incident.id),
            after_state={"category": payload.category, "severity": payload.severity},
            correlation_id=correlation_id,
        )
        await self._session.commit()
        await self._session.refresh(incident)
        return IncidentResponse.model_validate(incident)
