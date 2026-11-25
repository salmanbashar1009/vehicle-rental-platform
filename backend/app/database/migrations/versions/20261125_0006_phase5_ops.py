"""Phase 5 tables: maintenance_records, customer_comms_logs, and reviews.

Revision ID: 20261125_0006
Revises: 20261125_0005
Create Date: 2026-11-25 08:25:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "20261125_0006"
down_revision: str | None = "20261125_0005"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

UUID = postgresql.UUID(as_uuid=True)
TS = sa.DateTime(timezone=True)


def upgrade() -> None:
    """Create Phase 5 maintenance, CRM communications, and reviews tables."""
    op.create_table(
        "maintenance_records",
        sa.Column("id", UUID, primary_key=True),
        sa.Column(
            "vehicle_id", UUID, sa.ForeignKey("vehicles.id", ondelete="RESTRICT"), nullable=False
        ),
        sa.Column("maint_type", sa.String(32), nullable=False),
        sa.Column("description", sa.Text, nullable=False),
        sa.Column("provider_name", sa.String(160), nullable=True),
        sa.Column("scheduled_start", TS, nullable=False),
        sa.Column("scheduled_end", TS, nullable=False),
        sa.Column("cost_minor", sa.BigInteger, server_default="0", nullable=False),
        sa.Column("currency", sa.String(3), server_default="USD", nullable=False),
        sa.Column("odometer_km", sa.Integer, nullable=True),
        sa.Column("receipt_key", sa.String(255), nullable=True),
        sa.Column("status", sa.String(24), server_default="scheduled", nullable=False),
        sa.Column("created_by", UUID, nullable=False),
        sa.Column("created_at", TS, server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", TS, server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("scheduled_end > scheduled_start", name="ck_maint_window_valid"),
        sa.CheckConstraint("cost_minor >= 0", name="ck_maint_cost_nonneg"),
    )
    op.create_index("ix_maint_vehicle_id", "maintenance_records", ["vehicle_id"])

    op.create_table(
        "customer_comms_logs",
        sa.Column("id", UUID, primary_key=True),
        sa.Column(
            "customer_id",
            UUID,
            sa.ForeignKey("customer_profiles.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("channel", sa.String(24), nullable=False),
        sa.Column("summary", sa.Text, nullable=False),
        sa.Column("logged_by", UUID, nullable=False),
        sa.Column("created_at", TS, server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_comms_customer_id", "customer_comms_logs", ["customer_id"])

    op.create_table(
        "reviews",
        sa.Column("id", UUID, primary_key=True),
        sa.Column(
            "booking_id",
            UUID,
            sa.ForeignKey("bookings.id", ondelete="CASCADE"),
            unique=True,
            nullable=False,
        ),
        sa.Column("customer_id", UUID, sa.ForeignKey("customer_profiles.id"), nullable=False),
        sa.Column("driver_id", UUID, sa.ForeignKey("driver_profiles.id"), nullable=True),
        sa.Column("vehicle_id", UUID, sa.ForeignKey("vehicles.id"), nullable=True),
        sa.Column("overall_rating", sa.Integer, nullable=False),
        sa.Column("driver_rating", sa.Integer, nullable=False),
        sa.Column("vehicle_rating", sa.Integer, nullable=False),
        sa.Column("service_rating", sa.Integer, nullable=False),
        sa.Column("comment", sa.Text, nullable=True),
        sa.Column("moderation_status", sa.String(24), server_default="published", nullable=False),
        sa.Column("moderated_by", UUID, nullable=True),
        sa.Column("created_at", TS, server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("overall_rating BETWEEN 1 AND 5", name="ck_review_overall_1_5"),
        sa.CheckConstraint("driver_rating BETWEEN 1 AND 5", name="ck_review_driver_1_5"),
        sa.CheckConstraint("vehicle_rating BETWEEN 1 AND 5", name="ck_review_vehicle_1_5"),
        sa.CheckConstraint("service_rating BETWEEN 1 AND 5", name="ck_review_service_1_5"),
    )


def downgrade() -> None:
    """Drop Phase 5 tables."""
    op.drop_table("reviews")
    op.drop_table("customer_comms_logs")
    op.drop_table("maintenance_records")
