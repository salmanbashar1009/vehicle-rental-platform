"""Alembic async environment configuration."""

import asyncio
from logging.config import fileConfig

from alembic import context
from sqlalchemy import pool
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import async_engine_from_config

from app.core.config import get_settings
from app.core.idempotency import IdempotencyRecord  # noqa: F401
from app.database.base import Base
from app.modules.audit.models import AuditLog  # noqa: F401
from app.modules.authentication.models import AuthSession, PasswordResetToken  # noqa: F401
from app.modules.bookings.models import (  # noqa: F401
    Booking,
    BookingStatusHistory,
    BookingStop,
    Quotation,
)
from app.modules.crm.models import CustomerCommsLog  # noqa: F401
from app.modules.customers.models import CorporateAccount, CustomerProfile  # noqa: F401
from app.modules.dispatch.models import Assignment, AssignmentHistory  # noqa: F401
from app.modules.drivers.models import DriverProfile, DriverScheduleBlock  # noqa: F401
from app.modules.finance.models import Expense, Invoice, Payment, Refund  # noqa: F401
from app.modules.maintenance.models import MaintenanceRecord  # noqa: F401
from app.modules.notifications.models import Notification, NotificationOutbox  # noqa: F401
from app.modules.reviews.models import Review  # noqa: F401
from app.modules.services.models import (  # noqa: F401
    PricingRule,
    ServiceCategory,
    ServiceWorkflow,
)
from app.modules.tracking.models import LocationPoint  # noqa: F401
from app.modules.trips.models import IncidentReport, Trip, TripStatusEvent  # noqa: F401
from app.modules.users.models import (  # noqa: F401
    Permission,
    Role,
    RolePermission,
    User,
    UserRole,
)
from app.modules.vehicles.models import (  # noqa: F401
    Vehicle,
    VehicleDocument,
    VehicleImage,
    VehicleScheduleBlock,
)

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    """Run migrations in offline SQL mode."""
    url = get_settings().database_url
    context.configure(url=url, target_metadata=target_metadata, literal_binds=True)
    with context.begin_transaction():
        context.run_migrations()


def _do_run_migrations(connection: Connection) -> None:
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations() -> None:
    """Run migrations using asyncpg engine."""
    section = config.get_section(config.config_ini_section, {})
    section["sqlalchemy.url"] = get_settings().database_url
    connectable = async_engine_from_config(section, prefix="sqlalchemy.", poolclass=pool.NullPool)
    async with connectable.connect() as connection:
        await connection.run_sync(_do_run_migrations)
    await connectable.dispose()


def run_migrations_online() -> None:
    """Entry point for online migrations."""
    asyncio.run(run_async_migrations())


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
