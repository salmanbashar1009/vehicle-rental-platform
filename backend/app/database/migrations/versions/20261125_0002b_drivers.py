"""Driver profiles and exclusion-constrained schedule block tables.

Revision ID: 20261125_0002b
Revises: 20261125_0002
Create Date: 2026-11-25 01:41:30
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "20261125_0002b"
down_revision: str | None = "20261125_0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

UUID = postgresql.UUID(as_uuid=True)
TS = sa.DateTime(timezone=True)


def upgrade() -> None:
    """Create driver_profiles and driver_schedule_blocks tables."""
    op.create_table(
        "driver_profiles",
        sa.Column("id", UUID, primary_key=True),
        sa.Column(
            "user_id",
            UUID,
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            unique=True,
            nullable=False,
        ),
        sa.Column("licence_number", sa.String(64), unique=True, nullable=False),
        sa.Column("licence_classes_json", sa.JSON(), nullable=False),
        sa.Column("licence_expiry", sa.Date(), nullable=False),
        sa.Column("emergency_contact_name", sa.String(128), nullable=True),
        sa.Column("emergency_contact_phone", sa.String(32), nullable=True),
        sa.Column("photo_key", sa.String(255), nullable=True),
        sa.Column("employment_status", sa.String(32), nullable=False, server_default="active"),
        sa.Column("availability_status", sa.String(32), nullable=False, server_default="available"),
        sa.Column("created_at", TS, server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", TS, server_default=sa.func.now(), nullable=False),
        sa.Column("deleted_at", TS, nullable=True),
    )
    op.create_table(
        "driver_schedule_blocks",
        sa.Column("id", UUID, primary_key=True),
        sa.Column(
            "driver_id",
            UUID,
            sa.ForeignKey("driver_profiles.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("block_type", sa.String(32), nullable=False),
        sa.Column("source_id", UUID, nullable=False),
        sa.Column("time_range", postgresql.TSTZRANGE(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("created_at", TS, server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", TS, server_default=sa.func.now(), nullable=False),
        postgresql.ExcludeConstraint(
            ("driver_id", "="),
            ("time_range", "&&"),
            name="excl_driver_schedule_no_overlap",
            using="gist",
            where=sa.text("is_active = true"),
        ),
    )


def downgrade() -> None:
    """Drop driver tables."""
    op.drop_table("driver_schedule_blocks")
    op.drop_table("driver_profiles")
