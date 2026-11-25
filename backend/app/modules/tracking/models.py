"""Historical GPS location point ORM model."""

from datetime import UTC, datetime
from uuid import UUID, uuid4

from sqlalchemy import DateTime, ForeignKey, Index, Numeric, func
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base


class LocationPoint(Base):
    """Sampled GPS breadcrumb retained subject to configurable retention policy."""

    __tablename__ = "location_points"
    __table_args__ = (Index("ix_location_points_trip_recorded", "trip_id", "recorded_at"),)

    id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4)
    trip_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("trips.id", ondelete="CASCADE"), nullable=False
    )
    driver_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("driver_profiles.id"), nullable=False
    )
    lat: Mapped[float] = mapped_column(Numeric(9, 6), nullable=False)
    lng: Mapped[float] = mapped_column(Numeric(9, 6), nullable=False)
    accuracy_m: Mapped[float | None] = mapped_column(Numeric(7, 2), nullable=True)
    speed_mps: Mapped[float | None] = mapped_column(Numeric(7, 2), nullable=True)
    heading_deg: Mapped[float | None] = mapped_column(Numeric(6, 2), nullable=True)
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC), server_default=func.now()
    )
