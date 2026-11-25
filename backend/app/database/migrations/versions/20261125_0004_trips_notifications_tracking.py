"""Notifications, trips, incidents, and GPS location_points tables.

Revision ID: 20261125_0004
Revises: 20261125_0003
Create Date: 2026-11-25 03:20:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "20261125_0004"
down_revision: str | None = "20261125_0003"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

UUID = postgresql.UUID(as_uuid=True)
TS = sa.DateTime(timezone=True)


def upgrade() -> None:
    """Create Phase 2 and Phase 3 operational tables."""
    op.create_table(
        "notifications",
        sa.Column("id", UUID, primary_key=True),
        sa.Column("user_id", UUID, sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("event_type", sa.String(64), nullable=False),
        sa.Column("title", sa.String(160), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("priority", sa.String(16), nullable=False, server_default="normal"),
        sa.Column("resource_type", sa.String(64), nullable=True),
        sa.Column("resource_id", sa.String(128), nullable=True),
        sa.Column("is_read", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("created_at", TS, server_default=sa.func.now(), nullable=False),
    )
    op.create_table(
        "notification_outbox",
        sa.Column("id", UUID, primary_key=True),
        sa.Column("dedup_key", sa.String(160), unique=True, nullable=False),
        sa.Column("recipient_user_id", UUID, nullable=True),
        sa.Column("channel", sa.String(24), nullable=False),
        sa.Column("event_type", sa.String(64), nullable=False),
        sa.Column("payload_json", sa.JSON(), nullable=False),
        sa.Column("status", sa.String(24), nullable=False, server_default="pending"),
        sa.Column("attempts", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("next_retry_at", TS, server_default=sa.func.now(), nullable=False),
        sa.Column("last_error", sa.Text(), nullable=True),
        sa.Column("created_at", TS, server_default=sa.func.now(), nullable=False),
    )
    op.create_table(
        "trips",
        sa.Column("id", UUID, primary_key=True),
        sa.Column(
            "assignment_id",
            UUID,
            sa.ForeignKey("assignments.id", ondelete="CASCADE"),
            unique=True,
            nullable=False,
        ),
        sa.Column("status", sa.String(48), nullable=False, server_default="assigned"),
        sa.Column("started_at", TS, nullable=True),
        sa.Column("completed_at", TS, nullable=True),
        sa.Column("start_odometer", sa.Integer(), nullable=True),
        sa.Column("end_odometer", sa.Integer(), nullable=True),
        sa.Column("actual_distance_km", sa.Numeric(9, 2), nullable=True),
        sa.Column("waiting_minutes", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column(
            "extra_charges_minor", sa.BigInteger(), nullable=False, server_default=sa.text("0")
        ),
        sa.Column("currency", sa.String(3), nullable=False, server_default="USD"),
        sa.Column("signature_key", sa.String(255), nullable=True),
        sa.Column("completion_notes", sa.Text(), nullable=True),
        sa.Column("admin_reviewed_by", UUID, nullable=True),
        sa.Column("created_at", TS, server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", TS, server_default=sa.func.now(), nullable=False),
    )
    op.create_table(
        "trip_status_events",
        sa.Column("id", UUID, primary_key=True),
        sa.Column("trip_id", UUID, sa.ForeignKey("trips.id", ondelete="CASCADE"), nullable=False),
        sa.Column("milestone", sa.String(48), nullable=False),
        sa.Column("occurred_at", TS, nullable=False),
        sa.Column("lat", sa.Numeric(9, 6), nullable=True),
        sa.Column("lng", sa.Numeric(9, 6), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("idempotency_key", sa.String(128), unique=True, nullable=False),
        sa.Column("created_at", TS, server_default=sa.func.now(), nullable=False),
    )
    op.create_table(
        "incident_reports",
        sa.Column("id", UUID, primary_key=True),
        sa.Column("trip_id", UUID, sa.ForeignKey("trips.id", ondelete="CASCADE"), nullable=False),
        sa.Column("driver_id", UUID, sa.ForeignKey("driver_profiles.id"), nullable=False),
        sa.Column("category", sa.String(32), nullable=False),
        sa.Column("severity", sa.String(16), nullable=False, server_default="high"),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("lat", sa.Numeric(9, 6), nullable=True),
        sa.Column("lng", sa.Numeric(9, 6), nullable=True),
        sa.Column("photos_json", sa.JSON(), nullable=False),
        sa.Column("status", sa.String(24), nullable=False, server_default="open"),
        sa.Column("resolved_by", UUID, nullable=True),
        sa.Column("created_at", TS, server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", TS, server_default=sa.func.now(), nullable=False),
    )
    op.create_table(
        "location_points",
        sa.Column("id", UUID, primary_key=True),
        sa.Column("trip_id", UUID, sa.ForeignKey("trips.id", ondelete="CASCADE"), nullable=False),
        sa.Column("driver_id", UUID, sa.ForeignKey("driver_profiles.id"), nullable=False),
        sa.Column("lat", sa.Numeric(9, 6), nullable=False),
        sa.Column("lng", sa.Numeric(9, 6), nullable=False),
        sa.Column("accuracy_m", sa.Numeric(7, 2), nullable=True),
        sa.Column("speed_mps", sa.Numeric(7, 2), nullable=True),
        sa.Column("heading_deg", sa.Numeric(6, 2), nullable=True),
        sa.Column("recorded_at", TS, nullable=False),
        sa.Column("created_at", TS, server_default=sa.func.now(), nullable=False),
    )
    op.create_index(
        "ix_location_points_trip_recorded", "location_points", ["trip_id", "recorded_at"]
    )


def downgrade() -> None:
    """Drop Phase 2 and Phase 3 operational tables."""
    for name in (
        "location_points",
        "incident_reports",
        "trip_status_events",
        "trips",
        "notification_outbox",
        "notifications",
    ):
        op.drop_table(name)
