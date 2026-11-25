"""Async Redis client factory and sliding-window rate limiter."""

from redis.asyncio import Redis

from app.core.config import get_settings
from app.core.exceptions import RateLimitError

_redis_client: Redis | None = None


def get_redis_client() -> Redis:
    """Return singleton async Redis client."""
    global _redis_client
    if _redis_client is None:
        settings = get_settings()
        _redis_client = Redis.from_url(settings.redis_url, decode_responses=True)
    return _redis_client


async def close_redis_client() -> None:
    """Close Redis connection pool on shutdown."""
    global _redis_client
    if _redis_client is not None:
        await _redis_client.aclose()
        _redis_client = None


async def enforce_rate_limit(
    redis: Redis,
    *,
    key: str,
    max_attempts: int,
    window_seconds: int,
    message: str = "Too many requests. Please try again later.",
) -> int:
    """Increment counter with TTL and raise RateLimitError when exceeded."""
    current = await redis.incr(key)
    if current == 1:
        await redis.expire(key, window_seconds)
    if current > max_attempts:
        raise RateLimitError(message)
    return int(current)
