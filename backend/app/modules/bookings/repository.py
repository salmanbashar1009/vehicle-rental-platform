"""Repository for booking and quotation persistence queries."""

from uuid import UUID

from sqlalchemy import ColumnElement, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.pagination import PaginationParams
from app.modules.bookings.models import Booking, Quotation


class BookingRepository:
    """Data access layer for bookings and quotations."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_id(self, booking_id: UUID, *, for_update: bool = False) -> Booking | None:
        """Fetch non-deleted booking by UUID with optional row lock."""
        stmt = select(Booking).where(Booking.id == booking_id, Booking.deleted_at.is_(None))
        if for_update:
            stmt = stmt.with_for_update()
        return (await self._session.execute(stmt)).scalar_one_or_none()

    async def get_by_reference(self, reference: str) -> Booking | None:
        """Fetch booking by human-readable reference."""
        stmt = select(Booking).where(
            Booking.reference == reference.strip().upper(), Booking.deleted_at.is_(None)
        )
        return (await self._session.execute(stmt)).scalar_one_or_none()

    async def list_bookings(
        self,
        *,
        pagination: PaginationParams,
        customer_id: UUID | None = None,
        status: str | None = None,
        search: str | None = None,
    ) -> tuple[list[Booking], int]:
        """List filtered paginated bookings."""
        filters: list[ColumnElement[bool]] = [Booking.deleted_at.is_(None)]
        if customer_id is not None:
            filters.append(Booking.customer_id == customer_id)
        if status:
            filters.append(Booking.status == status)
        if search:
            filters.append(Booking.reference.ilike(f"%{search.strip()}%"))

        total = int(
            (
                await self._session.execute(select(func.count(Booking.id)).where(*filters))
            ).scalar_one()
        )
        rows = (
            (
                await self._session.execute(
                    select(Booking)
                    .where(*filters)
                    .order_by(Booking.created_at.desc())
                    .offset(pagination.offset)
                    .limit(pagination.page_size)
                )
            )
            .scalars()
            .all()
        )
        return list(rows), total

    async def get_quotation(self, quotation_id: UUID) -> Quotation | None:
        """Fetch quotation by UUID."""
        stmt = select(Quotation).where(Quotation.id == quotation_id)
        return (await self._session.execute(stmt)).scalar_one_or_none()
