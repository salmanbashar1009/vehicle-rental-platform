"""Service category, workflow, and pricing rule ORM models."""

from typing import Any
from uuid import UUID

from sqlalchemy import JSON, BigInteger, Boolean, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import TSTZRANGE
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base, UUIDTimestampMixin


class ServiceCategory(Base, UUIDTimestampMixin):
    """Transport service category (Tour, Event, Cargo, Airport, Corporate, etc.)."""

    __tablename__ = "service_categories"

    slug: Mapped[str] = mapped_column(String(64), unique=True, nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(128), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    requires_quote: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    display_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    workflow: Mapped["ServiceWorkflow | None"] = relationship(
        back_populates="category", uselist=False, lazy="selectin"
    )


class ServiceWorkflow(Base, UUIDTimestampMixin):
    """Configurable milestone workflow and dynamic booking form schema per service."""

    __tablename__ = "service_workflows"

    service_category_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("service_categories.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    steps_json: Mapped[list[str]] = mapped_column(JSON, nullable=False)
    form_schema_json: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict, nullable=False)

    category: Mapped[ServiceCategory] = relationship(back_populates="workflow")


class PricingRule(Base, UUIDTimestampMixin):
    """Server-side pricing parameters for indicative estimates and quote templates."""

    __tablename__ = "pricing_rules"

    service_category_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("service_categories.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    vehicle_category: Mapped[str] = mapped_column(String(64), nullable=False)
    base_minor: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    per_km_minor: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    per_hour_minor: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    waiting_per_hour_minor: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    driver_allowance_minor: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    seasonal_multiplier_bps: Mapped[int] = mapped_column(Integer, nullable=False, default=10000)
    currency: Mapped[str] = mapped_column(String(3), nullable=False, default="USD")
    effective_range: Mapped[Any | None] = mapped_column(TSTZRANGE, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
