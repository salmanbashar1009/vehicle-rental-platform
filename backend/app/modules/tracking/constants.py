"""Tracking privacy window constants and freshness classification helper."""

from datetime import UTC, datetime

ACTIVE_TRACKING_STEPS = frozenset(
    {
        "en_route_to_pickup",
        "arrived_at_pickup",
        "loading_started",
        "loading_completed",
        "picked_up",
        "journey_started",
        "at_destination",
        "unloading_started",
        "unloading_completed",
    }
)


def compute_freshness(recorded_at: datetime | None, *, interrupted: bool = False) -> str:
    """Classify GPS freshness per shared-contracts/websocket-protocol.md."""
    if interrupted or recorded_at is None:
        return "offline"
    age = (datetime.now(UTC) - recorded_at).total_seconds()
    if age <= 60:
        return "live"
    if age <= 300:
        return "stale"
    return "offline"
