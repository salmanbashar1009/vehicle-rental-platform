"""Read queries, fleet live map aggregation, playback, and GPS retention purge."""

from collections.abc import Awaitable
from datetime import UTC, datetime, timedelta
from typing import Any, cast
from uuid import UUID

from redis.asyncio import Redis
from sqlalchemy import CursorResult, delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.exceptions import ForbiddenError, NotFoundError
from app.modules.bookings.models import Booking
from app.modules.customers.models import CustomerProfile
from app.modules.dispatch.models import Assignment
from app.modules.drivers.models import DriverProfile
from app.modules.tracking.constants import ACTIVE_TRACKING_STEPS, compute_freshness
from app.modules.tracking.models import LocationPoint
from app.modules.tracking.schemas import (
    BookingTrackingResponse,
    RoutePointResponse,
    VehicleLiveLocationResponse,
)
from app.modules.trips.models import Trip
from app.modules.vehicles.models import Vehicle


class TrackingQueryService:
    """Provides fleet live map, customer tracking view, route playback, and retention purge."""

    def __init__(self, session: AsyncSession, redis: Redis) -> None:
        self._session = session
        self._redis = redis

    async def _get_cached_location(self, vehicle_id: UUID) -> dict[str, str]:
        raw = cast(
            Awaitable[dict[str, str]],
            self._redis.hgetall(f"vehicle:latest:{vehicle_id}"),
        )
        return await raw

    async def get_fleet_live(self) -> list[VehicleLiveLocationResponse]:
        """Return all currently active trips with latest Redis location and freshness."""
        stmt = (
            select(Trip, Assignment, Vehicle, DriverProfile, Booking)
            .join(Assignment, Trip.assignment_id == Assignment.id)
            .join(Vehicle, Assignment.vehicle_id == Vehicle.id)
            .join(DriverProfile, Assignment.driver_id == DriverProfile.id)
            .join(Booking, Assignment.booking_id == Booking.id)
            .where(Trip.status.in_(ACTIVE_TRACKING_STEPS), Assignment.is_current.is_(True))
        )
        rows = (await self._session.execute(stmt)).all()
        out: list[VehicleLiveLocationResponse] = []
        for trip, _assign, vehicle, driver, booking in rows:
            cached = await self._get_cached_location(vehicle.id)
            rec_at = (
                datetime.fromisoformat(cached["recorded_at"]) if "recorded_at" in cached else None
            )
            interrupted = cached.get("interrupted") == "1"
            out.append(
                VehicleLiveLocationResponse(
                    vehicle_id=vehicle.id,
                    vehicle_plate=vehicle.plate_number,
                    vehicle_name=vehicle.name,
                    driver_id=driver.id,
                    driver_name=driver.user.full_name,
                    booking_id=booking.id,
                    booking_reference=booking.reference,
                    trip_id=trip.id,
                    trip_status=trip.status,
                    lat=float(cached["lat"]) if "lat" in cached else None,
                    lng=float(cached["lng"]) if "lng" in cached else None,
                    accuracy_m=float(cached["accuracy_m"]) if "accuracy_m" in cached else None,
                    speed_mps=float(cached["speed_mps"]) if "speed_mps" in cached else None,
                    heading_deg=float(cached["heading_deg"]) if "heading_deg" in cached else None,
                    recorded_at=rec_at,
                    freshness=compute_freshness(rec_at, interrupted=interrupted),
                )
            )
        return out

    async def get_booking_tracking(
        self, booking_id: UUID, *, user_id: UUID, is_staff: bool
    ) -> BookingTrackingResponse:
        """Return active trip tracking info enforcing booking ownership and policy."""
        booking = (
            await self._session.execute(
                select(Booking).where(Booking.id == booking_id, Booking.deleted_at.is_(None))
            )
        ).scalar_one_or_none()
        if booking is None:
            raise NotFoundError("Booking not found.")
        if not is_staff:
            profile = (
                await self._session.execute(
                    select(CustomerProfile).where(CustomerProfile.user_id == user_id)
                )
            ).scalar_one_or_none()
            if profile is None or booking.customer_id != profile.id:
                raise ForbiddenError("You do not have access to this booking's tracking.")

        stops = [
            {"seq_order": s.seq_order, "stop_type": s.stop_type, "address": s.address}
            for s in booking.stops
        ]
        assign = (
            await self._session.execute(
                select(Assignment).where(
                    Assignment.booking_id == booking.id, Assignment.is_current.is_(True)
                )
            )
        ).scalar_one_or_none()
        trip = (
            (
                await self._session.execute(select(Trip).where(Trip.assignment_id == assign.id))
            ).scalar_one_or_none()
            if assign
            else None
        )
        if (
            not booking.tracking_enabled
            or assign is None
            or trip is None
            or trip.status not in ACTIVE_TRACKING_STEPS
        ):
            return BookingTrackingResponse(
                booking_id=booking.id,
                booking_reference=booking.reference,
                trip_status=trip.status if trip else booking.status,
                tracking_active=False,
                freshness="offline",
                stops=stops,
            )

        vehicle = (
            await self._session.execute(select(Vehicle).where(Vehicle.id == assign.vehicle_id))
        ).scalar_one()
        driver = (
            await self._session.execute(
                select(DriverProfile).where(DriverProfile.id == assign.driver_id)
            )
        ).scalar_one()
        cached = await self._get_cached_location(vehicle.id)
        rec_at = datetime.fromisoformat(cached["recorded_at"]) if "recorded_at" in cached else None
        return BookingTrackingResponse(
            booking_id=booking.id,
            booking_reference=booking.reference,
            trip_status=trip.status,
            tracking_active=True,
            vehicle_name=vehicle.name,
            vehicle_plate=vehicle.plate_number,
            driver_display_name=driver.user.full_name.split()[0],
            lat=float(cached["lat"]) if "lat" in cached else None,
            lng=float(cached["lng"]) if "lng" in cached else None,
            recorded_at=rec_at,
            freshness=compute_freshness(rec_at, interrupted=cached.get("interrupted") == "1"),
            stops=stops,
        )

    async def get_trip_route(self, trip_id: UUID) -> list[RoutePointResponse]:
        """Return historical breadcrumbs for authorized admin playback."""
        rows = (
            (
                await self._session.execute(
                    select(LocationPoint)
                    .where(LocationPoint.trip_id == trip_id)
                    .order_by(LocationPoint.recorded_at.asc())
                )
            )
            .scalars()
            .all()
        )
        return [RoutePointResponse.model_validate(r) for r in rows]

    async def purge_expired_locations(self) -> int:
        """Delete GPS breadcrumbs older than configured gps_retention_days."""
        cutoff = datetime.now(UTC) - timedelta(days=get_settings().gps_retention_days)
        res = cast(
            CursorResult[Any],
            await self._session.execute(
                delete(LocationPoint).where(LocationPoint.recorded_at < cutoff)
            ),
        )
        await self._session.commit()
        return int(res.rowcount or 0)
