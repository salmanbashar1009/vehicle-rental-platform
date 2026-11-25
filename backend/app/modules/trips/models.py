"""Trip, status event, and incident report ORM models."""

from datetime import UTC, datetime
from uuid import UUID, uuid4

from sqlalchemy import JSON, BigInteger, DateTime, ForeignKey, Integer, Numeric, String, Text, func
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base, UUIDTimestampMixin


class Trip(Base, UUIDTimestampMixin):
    """Operational trip execution record linked 1:1 with an Assignment."""

    __tablename__ = "trips"

    assignment_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("assignments.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    status: Mapped[str] = mapped_column(String(48), default="assigned", nullable=False, index=True)
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    start_odometer: Mapped[int | None] = mapped_column(Integer, nullable=True)
    end_odometer: Mapped[int | None] = mapped_column(Integer, nullable=True)
    actual_distance_km: Mapped[float | None] = mapped_column(Numeric(9, 2), nullable=True)
    waiting_minutes: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    extra_charges_minor: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    currency: Mapped[str] = mapped_column(String(3), default="USD", nullable=False)
    signature_key: Mapped[str | None] = mapped_column(String(255), nullable=True)
    completion_notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    admin_reviewed_by: Mapped[UUID | None] = mapped_column(PG_UUID(as_uuid=True), nullable=True)

    events: Mapped[list["TripStatusEvent"]] = relationship(
        back_populates="trip",
        cascade="all, delete-orphan",
        order_by="TripStatusEvent.occurred_at",
        lazy="selectin",
    )


class TripStatusEvent(Base):
    """Chronological milestone audit event submitted by driver (offline-sync safe)."""

    __tablename__ = "trip_status_events"

    id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4)
    trip_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("trips.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    milestone: Mapped[str] = mapped_column(String(48), nullable=False)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    lat: Mapped[float | None] = mapped_column(Numeric(9, 6), nullable=True)
    lng: Mapped[float | None] = mapped_column(Numeric(9, 6), nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    idempotency_key: Mapped[str] = mapped_column(String(128), unique=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC), server_default=func.now()
    )
    trip: Mapped[Trip] = relationship(back_populates="events")


class IncidentReport(Base, UUIDTimestampMixin):
    """Driver-reported breakdown, accident, medical, security, or customer dispute."""

    __tablename__ = "incident_reports"

    trip_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("trips.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    driver_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("driver_profiles.id"), nullable=False, index=True
    )
    category: Mapped[str] = mapped_column(String(32), nullable=False)
    severity: Mapped[str] = mapped_column(String(16), default="high", nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    lat: Mapped[float | None] = mapped_column(Numeric(9, 6), nullable=True)
    lng: Mapped[float | None] = mapped_column(Numeric(9, 6), nullable=True)
    photos_json: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    status: Mapped[str] = mapped_column(String(24), default="open", nullable=False, index=True)
    resolved_by: Mapped[UUID | None] = mapped_column(PG_UUID(as_uuid=True), nullable=True)
