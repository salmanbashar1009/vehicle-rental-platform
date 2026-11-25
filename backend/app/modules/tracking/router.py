"""FastAPI REST and WebSocket routers for live GPS tracking."""

import json
from uuid import UUID

from fastapi import APIRouter, Depends, Header, WebSocket, WebSocketDisconnect
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.idempotency import parse_idempotency_key
from app.core.redis_client import get_redis_client
from app.database.session import get_db_session
from app.modules.authentication.dependencies import (
    CurrentActor,
    get_current_actor,
    require_permissions,
    require_roles,
)
from app.modules.tracking.query_service import TrackingQueryService
from app.modules.tracking.schemas import (
    BookingTrackingResponse,
    GpsBatchRequest,
    GpsBatchResponse,
    RoutePointResponse,
    VehicleLiveLocationResponse,
)
from app.modules.tracking.service import TrackingService
from app.modules.tracking.ws_manager import ws_hub

router = APIRouter(tags=["Tracking & Real-Time"])


@router.post("/tracking/locations/batch", response_model=GpsBatchResponse)
async def ingest_gps_batch(
    payload: GpsBatchRequest,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    actor: CurrentActor = Depends(require_roles("driver")),
    session: AsyncSession = Depends(get_db_session),
    redis: Redis = Depends(get_redis_client),
) -> GpsBatchResponse:
    """Ingest driver GPS batch strictly during active authorized trip window."""
    valid_key = parse_idempotency_key(idempotency_key)
    return await TrackingService(session, redis).ingest_batch(
        payload, user_id=actor.user_id, idempotency_key=valid_key
    )


@router.get("/tracking/fleet/live", response_model=list[VehicleLiveLocationResponse])
async def get_live_fleet(
    _actor: CurrentActor = Depends(require_permissions("tracking.read")),
    session: AsyncSession = Depends(get_db_session),
    redis: Redis = Depends(get_redis_client),
) -> list[VehicleLiveLocationResponse]:
    """List active fleet vehicles and live Redis GPS freshness."""
    return await TrackingQueryService(session, redis).get_fleet_live()


@router.get("/bookings/{booking_id}/tracking", response_model=BookingTrackingResponse)
async def get_booking_tracking(
    booking_id: UUID,
    actor: CurrentActor = Depends(get_current_actor),
    session: AsyncSession = Depends(get_db_session),
    redis: Redis = Depends(get_redis_client),
) -> BookingTrackingResponse:
    """View active tracking for own booking (or staff with tracking.read)."""
    return await TrackingQueryService(session, redis).get_booking_tracking(
        booking_id,
        user_id=actor.user_id,
        is_staff=actor.has_permission("tracking.read"),
    )


@router.get("/tracking/trips/{trip_id}/route", response_model=list[RoutePointResponse])
async def get_trip_route_playback(
    trip_id: UUID,
    _actor: CurrentActor = Depends(require_permissions("tracking.read")),
    session: AsyncSession = Depends(get_db_session),
    redis: Redis = Depends(get_redis_client),
) -> list[RoutePointResponse]:
    """Return historical route playback points for authorized staff."""
    return await TrackingQueryService(session, redis).get_trip_route(trip_id)


@router.websocket("/ws")
async def websocket_endpoint(
    websocket: WebSocket, session: AsyncSession = Depends(get_db_session)
) -> None:
    """Authenticated WebSocket gateway supporting channel ACLs and ping/pong heartbeats."""
    await websocket.accept()
    auth_header = websocket.headers.get("authorization")
    bearer = auth_header[7:] if auth_header and auth_header.lower().startswith("bearer ") else None
    identity = await ws_hub.authenticate_socket(websocket, session, bearer)

    try:
        while True:
            raw = await websocket.receive_text()
            msg = json.loads(raw)
            mtype = msg.get("type")
            if mtype == "ping":
                await websocket.send_text('{"type":"pong"}')
                continue
            if mtype == "auth" and identity is None:
                identity = await ws_hub.authenticate_socket(
                    websocket, session, str(msg.get("token", ""))
                )
                if identity is None:
                    await websocket.close(code=4001)
                    return
                await websocket.send_text('{"type":"auth_ok"}')
                continue
            if identity is None:
                await websocket.close(code=4001)
                return
            if mtype == "subscribe":
                channel = str(msg.get("channel", ""))
                user_id, roles, perms = identity
                ok = await ws_hub.authorize_channel(
                    channel=channel,
                    user_id=user_id,
                    roles=roles,
                    perms=perms,
                    session=session,
                )
                if not ok:
                    await websocket.send_text('{"type":"error","code":"FORBIDDEN"}')
                    continue
                ws_hub.subscribe(websocket, channel)
                await websocket.send_text(json.dumps({"type": "subscribed", "channel": channel}))
    except WebSocketDisconnect:
        ws_hub.disconnect(websocket)
    except Exception:
        ws_hub.disconnect(websocket)
