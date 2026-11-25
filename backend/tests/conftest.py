"""Pytest fixtures for VeloFleet backend unit, API, security, and DB tests."""

import os
from collections.abc import AsyncIterator

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.core.config import get_settings
from app.core.redis_client import get_redis_client
from app.database.base import Base
from app.database.session import get_db_session
from app.main import create_app
from app.modules.services.seed import seed_service_categories
from app.modules.users.seed import seed_roles_and_permissions


async def _postgres_available(url: str) -> bool:
    engine = create_async_engine(url, pool_pre_ping=True)
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        return True
    except Exception:
        return False
    finally:
        await engine.dispose()


@pytest.fixture
async def db_engine_factory() -> AsyncIterator[async_sessionmaker[AsyncSession]]:
    """Create isolated test PostgreSQL schema and yield per-request session factory."""
    settings = get_settings()
    test_url = os.getenv("TEST_DATABASE_URL", settings.test_database_url)
    if not await _postgres_available(test_url):
        pytest.skip(
            "PostgreSQL test database is not reachable; start Postgres/Docker to run DB tests."
        )

    engine: AsyncEngine = create_async_engine(test_url, pool_pre_ping=True)
    async with engine.begin() as conn:
        await conn.execute(text("CREATE EXTENSION IF NOT EXISTS pgcrypto"))
        await conn.execute(text("CREATE EXTENSION IF NOT EXISTS btree_gist"))
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)

    factory = async_sessionmaker(bind=engine, class_=AsyncSession, expire_on_commit=False)
    async with factory() as seed_session:
        await seed_roles_and_permissions(seed_session)
        await seed_service_categories(seed_session)
        await seed_session.commit()

    yield factory
    await engine.dispose()


@pytest.fixture
async def db_session(
    db_engine_factory: async_sessionmaker[AsyncSession],
) -> AsyncIterator[AsyncSession]:
    """Yield a standalone test session for fixture setup."""
    async with db_engine_factory() as session:
        yield session


@pytest.fixture
async def client(
    db_engine_factory: async_sessionmaker[AsyncSession],
) -> AsyncIterator[AsyncClient]:
    """FastAPI AsyncClient providing a fresh AsyncSession per HTTP request."""
    app = create_app()

    async def _override_db() -> AsyncIterator[AsyncSession]:
        async with db_engine_factory() as session:
            yield session

    app.dependency_overrides[get_db_session] = _override_db
    try:
        redis = get_redis_client()
        await redis.flushdb()
    except Exception as exc:
        print(f"Redis unavailable in test fixture: {exc}")

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://testserver") as ac:
        yield ac
