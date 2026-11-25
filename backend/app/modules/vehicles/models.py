"""Vehicle, image, document, and exclusion-guarded schedule block ORM models."""

from datetime import date
from typing import Any
from uuid import UUID, uuid4

from sqlalchemy import (
    JSON,
    BigInteger,
    Boolean,
    Date,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    text,
)
from sqlalchemy.dialects.postgresql import TSTZRANGE, ExcludeConstraint
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base, SoftDeleteMixin, UUIDTimestampMixin


class Vehicle(Base, UUIDTimestampMixin, SoftDeleteMixin):
    """Fleet vehicle profile."""

    __tablename__ = "vehicles"

    plate_number: Mapped[str] = mapped_column(String(32), unique=True, nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    category: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    make: Mapped[str] = mapped_column(String(80), nullable=False)
    model: Mapped[str] = mapped_column(String(80), nullable=False)
    year: Mapped[int] = mapped_column(Integer, nullable=False)
    seat_capacity: Mapped[int] = mapped_column(Integer, nullable=False)
    luggage_capacity: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    cargo_volume_m3: Mapped[float | None] = mapped_column(Numeric(8, 2), nullable=True)
    fuel_type: Mapped[str] = mapped_column(String(32), nullable=False)
    facilities_json: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    indicative_daily_rate_minor: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    currency: Mapped[str] = mapped_column(String(3), nullable=False, default="USD")
    status: Mapped[str] = mapped_column(String(32), nullable=False, default="available", index=True)
    odometer_km: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    ownership_type: Mapped[str] = mapped_column(String(32), nullable=False, default="company_owned")
    is_public: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)

    images: Mapped[list["VehicleImage"]] = relationship(
        back_populates="vehicle", cascade="all, delete-orphan", lazy="selectin"
    )
    documents: Mapped[list["VehicleDocument"]] = relationship(
        back_populates="vehicle", cascade="all, delete-orphan", lazy="selectin"
    )


class VehicleImage(Base):
    """Stored S3 image reference for a vehicle."""

    __tablename__ = "vehicle_images"

    id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4)
    vehicle_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("vehicles.id", ondelete="CASCADE"), nullable=False
    )
    object_key: Mapped[str] = mapped_column(String(255), nullable=False)
    is_primary: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    vehicle: Mapped[Vehicle] = relationship(back_populates="images")


class VehicleDocument(Base, UUIDTimestampMixin):
    """Compliance documents (registration, insurance, fitness, permit) with expiry."""

    __tablename__ = "vehicle_documents"

    vehicle_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("vehicles.id", ondelete="CASCADE"), nullable=False
    )
    doc_type: Mapped[str] = mapped_column(String(32), nullable=False)
    doc_number: Mapped[str] = mapped_column(String(96), nullable=False)
    file_key: Mapped[str | None] = mapped_column(String(255), nullable=True)
    issued_at: Mapped[date | None] = mapped_column(Date, nullable=True)
    expires_at: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    vehicle: Mapped[Vehicle] = relationship(back_populates="documents")


class VehicleScheduleBlock(Base, UUIDTimestampMixin):
    """PostgreSQL exclusion-constrained reservation window preventing double-booking."""

    __tablename__ = "vehicle_schedule_blocks"
    __table_args__ = (
        ExcludeConstraint(
            ("vehicle_id", "="),
            ("time_range", "&&"),
            name="excl_vehicle_schedule_no_overlap",
            using="gist",
            where=text("is_active = true"),
        ),
    )

    vehicle_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("vehicles.id", ondelete="CASCADE"), nullable=False
    )
    block_type: Mapped[str] = mapped_column(String(32), nullable=False)
    source_id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), nullable=False, index=True)
    time_range: Mapped[Any] = mapped_column(TSTZRANGE, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
