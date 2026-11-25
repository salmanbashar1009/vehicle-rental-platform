"""Booking, stops, status history, and quotation ORM models."""

from datetime import UTC, datetime
from typing import Any
from uuid import UUID, uuid4

from sqlalchemy import (
    JSON,
    BigInteger,
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    func,
)
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base, SoftDeleteMixin, UUIDTimestampMixin


class Booking(Base, UUIDTimestampMixin, SoftDeleteMixin):
    """Customer reservation / service booking header."""

    __tablename__ = "bookings"
    __table_args__ = (
        CheckConstraint("expected_end_at > pickup_at", name="ck_booking_window_valid"),
    )

    reference: Mapped[str] = mapped_column(String(32), unique=True, nullable=False, index=True)
    customer_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("customer_profiles.id"), nullable=False, index=True
    )
    service_category_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("service_categories.id"), nullable=False, index=True
    )
    preferred_vehicle_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("vehicles.id"), nullable=True
    )
    status: Mapped[str] = mapped_column(String(32), default="requested", nullable=False, index=True)
    pickup_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    expected_end_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    passenger_count: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    luggage_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    cargo_details_json: Mapped[dict[str, Any] | None] = mapped_column(JSON, nullable=True)
    service_metadata_json: Mapped[dict[str, Any]] = mapped_column(
        JSON, default=dict, nullable=False
    )
    special_instructions: Mapped[str | None] = mapped_column(Text, nullable=True)
    internal_notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    tracking_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    claim_token_hash: Mapped[str | None] = mapped_column(String(64), nullable=True)

    stops: Mapped[list["BookingStop"]] = relationship(
        back_populates="booking",
        cascade="all, delete-orphan",
        order_by="BookingStop.seq_order",
        lazy="selectin",
    )
    status_history: Mapped[list["BookingStatusHistory"]] = relationship(
        back_populates="booking",
        cascade="all, delete-orphan",
        order_by="BookingStatusHistory.created_at",
        lazy="selectin",
    )
    quotations: Mapped[list["Quotation"]] = relationship(
        back_populates="booking",
        cascade="all, delete-orphan",
        order_by="Quotation.version.desc()",
        lazy="selectin",
    )


class BookingStop(Base):
    """Ordered pickup, intermediate stops, and destination for a booking."""

    __tablename__ = "booking_stops"

    id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4)
    booking_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("bookings.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    seq_order: Mapped[int] = mapped_column(Integer, nullable=False)
    stop_type: Mapped[str] = mapped_column(String(32), nullable=False)
    address: Mapped[str] = mapped_column(String(500), nullable=False)
    lat: Mapped[float | None] = mapped_column(Numeric(9, 6), nullable=True)
    lng: Mapped[float | None] = mapped_column(Numeric(9, 6), nullable=True)
    booking: Mapped[Booking] = relationship(back_populates="stops")


class BookingStatusHistory(Base):
    """Audit timeline of booking status transitions."""

    __tablename__ = "booking_status_history"

    id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4)
    booking_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("bookings.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    from_status: Mapped[str | None] = mapped_column(String(32), nullable=True)
    to_status: Mapped[str] = mapped_column(String(32), nullable=False)
    changed_by: Mapped[UUID | None] = mapped_column(PG_UUID(as_uuid=True), nullable=True)
    reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC), server_default=func.now()
    )
    booking: Mapped[Booking] = relationship(back_populates="status_history")


class Quotation(Base, UUIDTimestampMixin):
    """Versioned itemized quotation issued for a booking."""

    __tablename__ = "quotations"

    booking_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("bookings.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    items_json: Mapped[list[dict[str, Any]]] = mapped_column(JSON, nullable=False)
    subtotal_minor: Mapped[int] = mapped_column(BigInteger, nullable=False)
    discount_minor: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    tax_minor: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    total_minor: Mapped[int] = mapped_column(BigInteger, nullable=False)
    deposit_minor: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    currency: Mapped[str] = mapped_column(String(3), default="USD", nullable=False)
    valid_until: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    terms: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(32), default="sent", nullable=False, index=True)
    responded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    booking: Mapped[Booking] = relationship(back_populates="quotations")
