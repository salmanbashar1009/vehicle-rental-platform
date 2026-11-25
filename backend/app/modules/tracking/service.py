"""GPS ingestion, Redis latest-location caching, and WS live broadcast."""

import json
import math
from collections.abc import Awaitable
from datetime import UTC, datetime
from typing import cast
from uuid import UUID, uuid4

from redis.asyncio import Redis
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ForbiddenError
from app.core.idempotency import (
    compute_request_hash,
    get_idempotent_replay,
    save_idempotent_response,
)
from app.core.redis_client import enforce_rate_limit
from app.modules.dispatch.models import Assignment
from app.modules.drivers.models import DriverProfile
from app.modules.tracking.constants import ACTIVE_TRACKING_STEPS, compute_freshness
from app.modules.tracking.models import LocationPoint
from app.modules.tracking.schemas import GpsBatchRequest, GpsBatchResponse
from app.modules.tracking.ws_manager import ws_hub
from app.modules.trips.models import Trip


def _haversine_m(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    r = 6371000.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = math.radians(lat2 - lat1), math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.atan2(math.sqrt(a), math.sqrt(1 - a))


class TrackingService:
    """Rate-controlled GPS ingestion and Redis/WebSocket live dispatch."""

    def __init__(self, session: AsyncSession, redis: Redis) -> None:
        self._session = session
        self._redis = redis

    async def ingest_batch(
        self,
        payload: GpsBatchRequest,
        *,
        user_id: UUID,
        idempotency_key: str,
    ) -> GpsBatchResponse:
        """Validate active trip window, update Redis + WS, and persist sampled breadcrumbs."""
        actor_scope = f"gps:user:{user_id}"
        req_hash = compute_request_hash(payload.model_dump(mode="json"))
        replay = await get_idempotent_replay(
            self._session,
            actor_scope=actor_scope,
            idempotency_key=idempotency_key,
            request_hash=req_hash,
        )
        if replay is not None:
            return GpsBatchResponse.model_validate(replay)

        driver = (
            await self._session.execute(
                select(DriverProfile).where(DriverProfile.user_id == user_id)
            )
        ).scalar_one_or_none()
        if driver is None:
            raise ForbiddenError("Driver profile not found.")

        assignment = (
            await self._session.execute(
                select(Assignment).where(Assignment.id == payload.assignment_id)
            )
        ).scalar_one_or_none()
        if assignment is None or assignment.driver_id != driver.id or not assignment.is_current:
            raise ForbiddenError("Not authorized for this assignment.")

        trip = (
            await self._session.execute(select(Trip).where(Trip.assignment_id == assignment.id))
        ).scalar_one_or_none()
        if trip is None or trip.status not in ACTIVE_TRACKING_STEPS:
            raise ForbiddenError(
                "GPS tracking is only allowed during an active trip.",
                code="TRACKING_WINDOW_CLOSED",
            )

        await enforce_rate_limit(
            self._redis,
            key=f"rl:gps:{assignment.id}",
            max_attempts=30,
            window_seconds=60,
            message="GPS ingestion rate limit exceeded.",
        )

        sorted_pts = sorted(payload.points, key=lambda p: p.recorded_at)
        last_saved = (
            await self._session.execute(
                select(LocationPoint)
                .where(LocationPoint.trip_id == trip.id)
                .order_by(LocationPoint.recorded_at.desc())
                .limit(1)
            )
        ).scalar_one_or_none()

        persisted = 0
        prev_lat = float(last_saved.lat) if last_saved else None
        prev_lng = float(last_saved.lng) if last_saved else None
        prev_ts = last_saved.recorded_at if last_saved else None

        for pt in sorted_pts:
            should_save = prev_ts is None or (pt.recorded_at - prev_ts).total_seconds() >= 15
            if not should_save and prev_lat is not None and prev_lng is not None:
                should_save = _haversine_m(prev_lat, prev_lng, pt.lat, pt.lng) >= 15.0
            if should_save:
                self._session.add(
                    LocationPoint(
                        trip_id=trip.id,
                        driver_id=driver.id,
                        lat=pt.lat,
                        lng=pt.lng,
                        accuracy_m=pt.accuracy_m,
                        speed_mps=pt.speed_mps,
                        heading_deg=pt.heading_deg,
                        recorded_at=pt.recorded_at,
                    )
                )
                persisted += 1
                prev_lat, prev_lng, prev_ts = pt.lat, pt.lng, pt.recorded_at

        latest = sorted_pts[-1]
        freshness = compute_freshness(
            latest.recorded_at, interrupted=payload.interruption_status is not None
        )
        redis_key = f"vehicle:latest:{assignment.vehicle_id}"
        await cast(
            Awaitable[int],
            self._redis.hset(
                redis_key,
                mapping={
                    "lat": str(latest.lat),
                    "lng": str(latest.lng),
                    "accuracy_m": str(latest.accuracy_m or 0.0),
                    "speed_mps": str(latest.speed_mps or 0.0),
                    "heading_deg": str(latest.heading_deg or 0.0),
                    "recorded_at": latest.recorded_at.isoformat(),
                    "interrupted": "1" if payload.interruption_status else "0",
                },
            ),
        )
        await self._redis.expire(redis_key, 600)

        event: dict[str, object] = {
            "type": "vehicle.location",
            "event_id": str(uuid4()),
            "timestamp": datetime.now(UTC).isoformat(),
            "payload": {
                "vehicle_id": str(assignment.vehicle_id),
                "booking_id": str(assignment.booking_id),
                "assignment_id": str(assignment.id),
                "lat": latest.lat,
                "lng": latest.lng,
                "accuracy_m": latest.accuracy_m,
                "speed_mps": latest.speed_mps,
                "heading_deg": latest.heading_deg,
                "recorded_at": latest.recorded_at.isoformat(),
                "freshness": freshness,
            },
        }
        await self._redis.publish("admin:fleet", json.dumps(event))
        await ws_hub.broadcast("admin:fleet", event)
        await ws_hub.broadcast(f"booking:{assignment.booking_id}", event)

        resp = GpsBatchResponse(
            accepted_count=len(sorted_pts),
            persisted_count=persisted,
            freshness=freshness,
        )
        await save_idempotent_response(
            self._session,
            actor_scope=actor_scope,
            idempotency_key=idempotency_key,
            request_hash=req_hash,
            status_code=200,
            response_body=resp.model_dump(mode="json"),
            ttl_hours=2,
        )
        await self._session.commit()
        return resp
