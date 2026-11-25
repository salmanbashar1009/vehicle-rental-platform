"""Authenticated WebSocket manager with channel ACLs and Redis Pub/Sub bridge."""

import json
from collections import defaultdict
from collections.abc import Mapping
from uuid import UUID

from fastapi import WebSocket
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.logging import get_logger
from app.core.security import decode_access_token
from app.modules.bookings.models import Booking
from app.modules.customers.models import CustomerProfile
from app.modules.drivers.models import DriverProfile
from app.modules.users.repository import UserRepository

logger = get_logger(__name__)


class WebSocketHub:
    """Manages authenticated WebSocket connections and authorized channel subscriptions."""

    def __init__(self) -> None:
        self._channels: dict[str, set[WebSocket]] = defaultdict(set)
        self._socket_channels: dict[WebSocket, set[str]] = defaultdict(set)

    async def authenticate_socket(
        self, websocket: WebSocket, session: AsyncSession, token: str | None
    ) -> tuple[UUID, set[str], set[str]] | None:
        """Verify Bearer JWT and return (user_id, roles, permissions) or None."""
        if not token:
            return None
        try:
            payload = decode_access_token(token)
            user_id = UUID(str(payload["sub"]))
        except Exception:
            return None
        user = await UserRepository(session).get_by_id(user_id)
        if user is None or not user.is_active:
            return None
        roles = {r.slug for r in user.roles}
        perms = {p.code for r in user.roles for p in r.permissions}
        return user.id, roles, perms

    async def authorize_channel(
        self,
        *,
        channel: str,
        user_id: UUID,
        roles: set[str],
        perms: set[str],
        session: AsyncSession,
    ) -> bool:
        """Enforce strict RBAC and ownership predicates on WebSocket channels."""
        if channel == "admin:fleet":
            return "owner" in roles or "tracking.read" in perms or "dispatch.read" in perms

        if channel.startswith("booking:"):
            try:
                booking_id = UUID(channel.split(":", 1)[1])
            except ValueError:
                return False
            if "owner" in roles or "tracking.read" in perms:
                return True
            profile = (
                await session.execute(
                    select(CustomerProfile).where(CustomerProfile.user_id == user_id)
                )
            ).scalar_one_or_none()
            if profile is None:
                return False
            booking = (
                await session.execute(select(Booking).where(Booking.id == booking_id))
            ).scalar_one_or_none()
            return (
                booking is not None
                and booking.customer_id == profile.id
                and booking.tracking_enabled
            )

        if channel.startswith("driver:"):
            try:
                driver_id = UUID(channel.split(":", 1)[1])
            except ValueError:
                return False
            driver = (
                await session.execute(select(DriverProfile).where(DriverProfile.user_id == user_id))
            ).scalar_one_or_none()
            return driver is not None and driver.id == driver_id

        return False

    def subscribe(self, websocket: WebSocket, channel: str) -> None:
        """Register socket on an authorized channel."""
        self._channels[channel].add(websocket)
        self._socket_channels[websocket].add(channel)

    def disconnect(self, websocket: WebSocket) -> None:
        """Remove socket from all subscribed channels cleanly."""
        for channel in self._socket_channels.pop(websocket, set()):
            self._channels[channel].discard(websocket)
            if not self._channels[channel]:
                self._channels.pop(channel, None)

    async def broadcast(self, channel: str, message: Mapping[str, object]) -> None:
        """Send JSON event to all live sockets subscribed to channel."""
        sockets = list(self._channels.get(channel, ()))
        if not sockets:
            return
        raw = json.dumps(message, default=str)
        dead: list[WebSocket] = []
        for ws in sockets:
            try:
                await ws.send_text(raw)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.disconnect(ws)


ws_hub = WebSocketHub()
