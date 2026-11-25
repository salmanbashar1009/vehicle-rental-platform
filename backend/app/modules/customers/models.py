"""Customer profile and corporate account ORM models."""

from uuid import UUID

from sqlalchemy import BigInteger, Boolean, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, SoftDeleteMixin, UUIDTimestampMixin


class CorporateAccount(Base, UUIDTimestampMixin):
    """B2B corporate account with negotiated terms."""

    __tablename__ = "corporate_accounts"

    company_name: Mapped[str] = mapped_column(String(200), nullable=False)
    tax_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    billing_cycle: Mapped[str] = mapped_column(String(32), default="monthly", nullable=False)
    credit_limit_minor: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    currency: Mapped[str] = mapped_column(String(3), default="USD", nullable=False)
    negotiated_discount_bps: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)


class CustomerProfile(Base, UUIDTimestampMixin, SoftDeleteMixin):
    """Individual or corporate customer profile (optionally linked to a User)."""

    __tablename__ = "customer_profiles"

    user_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        unique=True,
        nullable=True,
    )
    corporate_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("corporate_accounts.id", ondelete="SET NULL"),
        nullable=True,
    )
    customer_type: Mapped[str] = mapped_column(String(32), default="individual", nullable=False)
    full_name: Mapped[str] = mapped_column(String(160), nullable=False)
    email: Mapped[str | None] = mapped_column(String(255), nullable=True, index=True)
    phone: Mapped[str | None] = mapped_column(String(32), nullable=True, index=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
