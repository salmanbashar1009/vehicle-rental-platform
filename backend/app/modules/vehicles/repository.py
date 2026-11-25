"""Repository for vehicle queries and schedule conflict checks."""

from datetime import datetime
from uuid import UUID

from asyncpg.types import Range
from sqlalchemy import ColumnElement, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.pagination import PaginationParams
from app.modules.vehicles.models import Vehicle, VehicleScheduleBlock


class VehicleRepository:
    """Data access layer for vehicles and schedule blocks."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_id(self, vehicle_id: UUID) -> Vehicle | None:
        """Fetch non-deleted vehicle by UUID."""
        stmt = select(Vehicle).where(Vehicle.id == vehicle_id, Vehicle.deleted_at.is_(None))
        return (await self._session.execute(stmt)).scalar_one_or_none()

    async def get_by_plate(self, plate_number: str) -> Vehicle | None:
        """Fetch vehicle by normalized plate number."""
        stmt = select(Vehicle).where(
            func.upper(Vehicle.plate_number) == plate_number.strip().upper(),
            Vehicle.deleted_at.is_(None),
        )
        return (await self._session.execute(stmt)).scalar_one_or_none()

    async def list_vehicles(
        self,
        *,
        pagination: PaginationParams,
        category: str | None = None,
        min_seats: int | None = None,
        max_rate_minor: int | None = None,
        facility: str | None = None,
        public_only: bool = False,
    ) -> tuple[list[Vehicle], int]:
        """List filtered paginated vehicles."""
        filters: list[ColumnElement[bool]] = [Vehicle.deleted_at.is_(None)]
        if public_only:
            filters.append(Vehicle.is_public.is_(True))
        if category:
            filters.append(Vehicle.category == category)
        if min_seats is not None:
            filters.append(Vehicle.seat_capacity >= min_seats)
        if max_rate_minor is not None:
            filters.append(Vehicle.indicative_daily_rate_minor <= max_rate_minor)

        base = select(Vehicle).where(*filters)
        if facility:
            rows_all = list((await self._session.execute(base.order_by(Vehicle.name))).scalars())
            filtered = [v for v in rows_all if facility in v.facilities_json]
            total = len(filtered)
            return filtered[pagination.offset : pagination.offset + pagination.page_size], total

        total = int(
            (
                await self._session.execute(select(func.count(Vehicle.id)).where(*filters))
            ).scalar_one()
        )
        rows = (
            (
                await self._session.execute(
                    base.order_by(Vehicle.created_at.desc())
                    .offset(pagination.offset)
                    .limit(pagination.page_size)
                )
            )
            .scalars()
            .all()
        )
        return list(rows), total

    async def overlapping_vehicle_ids(
        self,
        *,
        start_at: datetime,
        end_at: datetime,
        exclude_source_id: UUID | None = None,
    ) -> set[UUID]:
        """Return vehicle IDs with active schedule blocks overlapping [start_at, end_at)."""
        window = Range(start_at, end_at, lower_inc=True, upper_inc=False)
        stmt = select(VehicleScheduleBlock.vehicle_id).where(
            VehicleScheduleBlock.is_active.is_(True),
            VehicleScheduleBlock.time_range.op("&&")(window),
        )
        if exclude_source_id is not None:
            stmt = stmt.where(VehicleScheduleBlock.source_id != exclude_source_id)
        return set((await self._session.execute(stmt)).scalars().all())

    async def get_calendar_blocks(
        self, vehicle_id: UUID, *, start_at: datetime, end_at: datetime
    ) -> list[VehicleScheduleBlock]:
        """Return active schedule blocks intersecting the requested range."""
        window = Range(start_at, end_at, lower_inc=True, upper_inc=False)
        stmt = (
            select(VehicleScheduleBlock)
            .where(
                VehicleScheduleBlock.vehicle_id == vehicle_id,
                VehicleScheduleBlock.is_active.is_(True),
                VehicleScheduleBlock.time_range.op("&&")(window),
            )
            .order_by(VehicleScheduleBlock.created_at.asc())
        )
        return list((await self._session.execute(stmt)).scalars().all())
