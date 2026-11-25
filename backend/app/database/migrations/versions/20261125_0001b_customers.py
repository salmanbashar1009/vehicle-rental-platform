"""Corporate accounts and customer profile tables.

Revision ID: 20261125_0001b
Revises: 20261125_0001
Create Date: 2026-11-25 01:40:30
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "20261125_0001b"
down_revision: str | None = "20261125_0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

UUID = postgresql.UUID(as_uuid=True)
TS = sa.DateTime(timezone=True)


def upgrade() -> None:
    """Create corporate_accounts and customer_profiles tables."""
    op.create_table(
        "corporate_accounts",
        sa.Column("id", UUID, primary_key=True),
        sa.Column("company_name", sa.String(200), nullable=False),
        sa.Column("tax_id", sa.String(64), nullable=True),
        sa.Column("billing_cycle", sa.String(32), nullable=False, server_default="monthly"),
        sa.Column(
            "credit_limit_minor", sa.BigInteger(), nullable=False, server_default=sa.text("0")
        ),
        sa.Column("currency", sa.String(3), nullable=False, server_default="USD"),
        sa.Column(
            "negotiated_discount_bps", sa.Integer(), nullable=False, server_default=sa.text("0")
        ),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("created_at", TS, server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", TS, server_default=sa.func.now(), nullable=False),
    )
    op.create_table(
        "customer_profiles",
        sa.Column("id", UUID, primary_key=True),
        sa.Column(
            "user_id",
            UUID,
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            unique=True,
            nullable=True,
        ),
        sa.Column(
            "corporate_id",
            UUID,
            sa.ForeignKey("corporate_accounts.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("customer_type", sa.String(32), nullable=False, server_default="individual"),
        sa.Column("full_name", sa.String(160), nullable=False),
        sa.Column("email", sa.String(255), nullable=True),
        sa.Column("phone", sa.String(32), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("created_at", TS, server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", TS, server_default=sa.func.now(), nullable=False),
        sa.Column("deleted_at", TS, nullable=True),
    )


def downgrade() -> None:
    """Drop customer_profiles and corporate_accounts tables."""
    op.drop_table("customer_profiles")
    op.drop_table("corporate_accounts")
