"""Idempotent seed script for RBAC roles, permissions, and 8 service categories."""

import asyncio
import sys
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.database.session import dispose_engine, get_session_factory  # noqa: E402
from app.modules.services.seed import seed_service_categories  # noqa: E402
from app.modules.users.seed import seed_roles_and_permissions  # noqa: E402
from app.modules.vehicles.seed import seed_sample_vehicles  # noqa: E402


async def run_seed() -> None:
    """Seed core lookup data idempotently."""
    async with get_session_factory()() as session:
        await seed_roles_and_permissions(session)
        await seed_service_categories(session)
        await seed_sample_vehicles(session)
        await session.commit()
    await dispose_engine()


if __name__ == "__main__":
    asyncio.run(run_seed())
    print("Seed completed successfully.")
