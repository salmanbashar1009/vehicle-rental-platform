"""Service categories, pricing rules, and fleet vehicle tables.

Revision ID: 20261125_0002
Revises: 20261125_0001b
Create Date: 2026-11-25 01:41:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "20261125_0002"
down_revision: str | None = "20261125_0001b"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

UUID = postgresql.UUID(as_uuid=True)
TS = sa.DateTime(timezone=True)


def upgrade() -> None:
    """Create services and fleet vehicle tables."""
    op.create_table(
        "service_categories",
        sa.Column("id", UUID, primary_key=True),
        sa.Column("slug", sa.String(64), unique=True, nullable=False),
        sa.Column("name", sa.String(128), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("requires_quote", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("display_order", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("created_at", TS, server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", TS, server_default=sa.func.now(), nullable=False),
    )
    op.create_table(
        "service_workflows",
        sa.Column("id", UUID, primary_key=True),
        sa.Column(
            "service_category_id",
            UUID,
            sa.ForeignKey("service_categories.id", ondelete="CASCADE"),
            unique=True,
            nullable=False,
        ),
        sa.Column("steps_json", sa.JSON(), nullable=False),
        sa.Column("form_schema_json", sa.JSON(), nullable=False),
        sa.Column("created_at", TS, server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", TS, server_default=sa.func.now(), nullable=False),
    )
    op.create_table(
        "pricing_rules",
        sa.Column("id", UUID, primary_key=True),
        sa.Column(
            "service_category_id",
            UUID,
            sa.ForeignKey("service_categories.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("vehicle_category", sa.String(64), nullable=False),
        sa.Column("base_minor", sa.BigInteger(), nullable=False, server_default=sa.text("0")),
        sa.Column("per_km_minor", sa.BigInteger(), nullable=False, server_default=sa.text("0")),
        sa.Column("per_hour_minor", sa.BigInteger(), nullable=False, server_default=sa.text("0")),
        sa.Column(
            "waiting_per_hour_minor", sa.BigInteger(), nullable=False, server_default=sa.text("0")
        ),
        sa.Column(
            "driver_allowance_minor", sa.BigInteger(), nullable=False, server_default=sa.text("0")
        ),
        sa.Column(
            "seasonal_multiplier_bps", sa.Integer(), nullable=False, server_default=sa.text("10000")
        ),
        sa.Column("currency", sa.String(3), nullable=False, server_default="USD"),
        sa.Column("effective_range", postgresql.TSTZRANGE(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("created_at", TS, server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", TS, server_default=sa.func.now(), nullable=False),
    )
    op.create_table(
        "vehicles",
        sa.Column("id", UUID, primary_key=True),
        sa.Column("plate_number", sa.String(32), unique=True, nullable=False),
        sa.Column("name", sa.String(160), nullable=False),
        sa.Column("category", sa.String(64), nullable=False),
        sa.Column("make", sa.String(80), nullable=False),
        sa.Column("model", sa.String(80), nullable=False),
        sa.Column("year", sa.Integer(), nullable=False),
        sa.Column("seat_capacity", sa.Integer(), nullable=False),
        sa.Column("luggage_capacity", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("cargo_volume_m3", sa.Numeric(8, 2), nullable=True),
        sa.Column("fuel_type", sa.String(32), nullable=False),
        sa.Column("facilities_json", sa.JSON(), nullable=False),
        sa.Column("indicative_daily_rate_minor", sa.BigInteger(), nullable=True),
        sa.Column("currency", sa.String(3), nullable=False, server_default="USD"),
        sa.Column("status", sa.String(32), nullable=False, server_default="available"),
        sa.Column("odometer_km", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("ownership_type", sa.String(32), nullable=False, server_default="company_owned"),
        sa.Column("is_public", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("created_at", TS, server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", TS, server_default=sa.func.now(), nullable=False),
        sa.Column("deleted_at", TS, nullable=True),
    )
    op.create_table(
        "vehicle_images",
        sa.Column("id", UUID, primary_key=True),
        sa.Column(
            "vehicle_id", UUID, sa.ForeignKey("vehicles.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("object_key", sa.String(255), nullable=False),
        sa.Column("is_primary", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default=sa.text("0")),
    )
    op.create_table(
        "vehicle_documents",
        sa.Column("id", UUID, primary_key=True),
        sa.Column(
            "vehicle_id", UUID, sa.ForeignKey("vehicles.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("doc_type", sa.String(32), nullable=False),
        sa.Column("doc_number", sa.String(96), nullable=False),
        sa.Column("file_key", sa.String(255), nullable=True),
        sa.Column("issued_at", sa.Date(), nullable=True),
        sa.Column("expires_at", sa.Date(), nullable=False),
        sa.Column("created_at", TS, server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", TS, server_default=sa.func.now(), nullable=False),
    )
    op.create_table(
        "vehicle_schedule_blocks",
        sa.Column("id", UUID, primary_key=True),
        sa.Column(
            "vehicle_id", UUID, sa.ForeignKey("vehicles.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("block_type", sa.String(32), nullable=False),
        sa.Column("source_id", UUID, nullable=False),
        sa.Column("time_range", postgresql.TSTZRANGE(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("created_at", TS, server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", TS, server_default=sa.func.now(), nullable=False),
        postgresql.ExcludeConstraint(
            ("vehicle_id", "="),
            ("time_range", "&&"),
            name="excl_vehicle_schedule_no_overlap",
            using="gist",
            where=sa.text("is_active = true"),
        ),
    )


def downgrade() -> None:
    """Drop services and fleet vehicle tables."""
    for name in (
        "vehicle_schedule_blocks",
        "vehicle_documents",
        "vehicle_images",
        "vehicles",
        "pricing_rules",
        "service_workflows",
        "service_categories",
    ):
        op.drop_table(name)
