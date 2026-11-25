"""Post-trip customer review and moderation ORM model."""

from datetime import UTC, datetime
from uuid import UUID, uuid4

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base


class Review(Base):
    """Customer 1-5 rating and feedback submitted once per completed/closed booking."""

    __tablename__ = "reviews"
    __table_args__ = (
        CheckConstraint("overall_rating BETWEEN 1 AND 5", name="ck_review_overall_1_5"),
        CheckConstraint("driver_rating BETWEEN 1 AND 5", name="ck_review_driver_1_5"),
        CheckConstraint("vehicle_rating BETWEEN 1 AND 5", name="ck_review_vehicle_1_5"),
        CheckConstraint("service_rating BETWEEN 1 AND 5", name="ck_review_service_1_5"),
    )

    id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4)
    booking_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("bookings.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    customer_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("customer_profiles.id"), nullable=False
    )
    driver_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("driver_profiles.id"), nullable=True, index=True
    )
    vehicle_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("vehicles.id"), nullable=True, index=True
    )
    overall_rating: Mapped[int] = mapped_column(Integer, nullable=False)
    driver_rating: Mapped[int] = mapped_column(Integer, nullable=False)
    vehicle_rating: Mapped[int] = mapped_column(Integer, nullable=False)
    service_rating: Mapped[int] = mapped_column(Integer, nullable=False)
    comment: Mapped[str | None] = mapped_column(Text, nullable=True)
    moderation_status: Mapped[str] = mapped_column(
        String(24), default="published", nullable=False, index=True
    )
    moderated_by: Mapped[UUID | None] = mapped_column(PG_UUID(as_uuid=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        server_default=func.now(),
        nullable=False,
    )
