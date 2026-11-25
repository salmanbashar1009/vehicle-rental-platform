"""Driver profile and exclusion-constrained schedule block ORM models."""

from datetime import date
from typing import Any
from uuid import UUID

from sqlalchemy import JSON, Boolean, Date, ForeignKey, String, text
from sqlalchemy.dialects.postgresql import TSTZRANGE, ExcludeConstraint
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base, SoftDeleteMixin, UUIDTimestampMixin
from app.modules.users.models import User


class DriverProfile(Base, UUIDTimestampMixin, SoftDeleteMixin):
    """Chauffeur profile linked 1:1 to a platform User account."""

    __tablename__ = "driver_profiles"

    user_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    licence_number: Mapped[str] = mapped_column(String(64), unique=True, nullable=False, index=True)
    licence_classes_json: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    licence_expiry: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    emergency_contact_name: Mapped[str | None] = mapped_column(String(128), nullable=True)
    emergency_contact_phone: Mapped[str | None] = mapped_column(String(32), nullable=True)
    photo_key: Mapped[str | None] = mapped_column(String(255), nullable=True)
    employment_status: Mapped[str] = mapped_column(String(32), default="active", nullable=False)
    availability_status: Mapped[str] = mapped_column(
        String(32), default="available", nullable=False, index=True
    )

    user: Mapped[User] = relationship(lazy="selectin")


class DriverScheduleBlock(Base, UUIDTimestampMixin):
    """PostgreSQL exclusion-constrained driver schedule window."""

    __tablename__ = "driver_schedule_blocks"
    __table_args__ = (
        ExcludeConstraint(
            ("driver_id", "="),
            ("time_range", "&&"),
            name="excl_driver_schedule_no_overlap",
            using="gist",
            where=text("is_active = true"),
        ),
    )

    driver_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("driver_profiles.id", ondelete="CASCADE"), nullable=False
    )
    block_type: Mapped[str] = mapped_column(String(32), nullable=False)
    source_id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), nullable=False, index=True)
    time_range: Mapped[Any] = mapped_column(TSTZRANGE, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
