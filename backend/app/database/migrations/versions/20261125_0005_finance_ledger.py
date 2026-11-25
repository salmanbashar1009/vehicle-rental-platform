"""Finance ledger tables: invoices, payments, refunds, and expenses.

Revision ID: 20261125_0005
Revises: 20261125_0004
Create Date: 2026-11-25 06:45:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "20261125_0005"
down_revision: str | None = "20261125_0004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

UUID = postgresql.UUID(as_uuid=True)
TS = sa.DateTime(timezone=True)


def upgrade() -> None:
    """Create Phase 4 immutable financial ledger and expense tables."""
    op.create_table(
        "invoices",
        sa.Column("id", UUID, primary_key=True),
        sa.Column(
            "booking_id", UUID, sa.ForeignKey("bookings.id", ondelete="RESTRICT"), nullable=False
        ),
        sa.Column("invoice_number", sa.String(32), unique=True, nullable=False),
        sa.Column("agreed_minor", sa.BigInteger, nullable=False),
        sa.Column("extra_minor", sa.BigInteger, server_default="0", nullable=False),
        sa.Column("discount_minor", sa.BigInteger, server_default="0", nullable=False),
        sa.Column("tax_minor", sa.BigInteger, server_default="0", nullable=False),
        sa.Column("total_minor", sa.BigInteger, nullable=False),
        sa.Column("currency", sa.String(3), server_default="USD", nullable=False),
        sa.Column("line_items_json", sa.JSON, nullable=False),
        sa.Column("status", sa.String(24), server_default="issued", nullable=False),
        sa.Column("issued_at", TS, server_default=sa.func.now(), nullable=False),
        sa.Column("created_at", TS, server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", TS, server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("total_minor >= 0", name="ck_invoice_total_nonneg"),
    )
    op.create_index("ix_invoices_booking_id", "invoices", ["booking_id"])

    op.create_table(
        "payments",
        sa.Column("id", UUID, primary_key=True),
        sa.Column(
            "booking_id", UUID, sa.ForeignKey("bookings.id", ondelete="RESTRICT"), nullable=False
        ),
        sa.Column(
            "invoice_id", UUID, sa.ForeignKey("invoices.id", ondelete="SET NULL"), nullable=True
        ),
        sa.Column("payment_type", sa.String(24), nullable=False),
        sa.Column("method", sa.String(32), nullable=False),
        sa.Column("amount_minor", sa.BigInteger, nullable=False),
        sa.Column("currency", sa.String(3), server_default="USD", nullable=False),
        sa.Column("transaction_ref", sa.String(128), nullable=True),
        sa.Column("reconciliation_status", sa.String(24), server_default="pending", nullable=False),
        sa.Column("idempotency_key", sa.String(128), unique=True, nullable=False),
        sa.Column("recorded_by", UUID, nullable=False),
        sa.Column("notes", sa.Text, nullable=True),
        sa.Column("created_at", TS, server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("amount_minor > 0", name="ck_payment_amount_positive"),
    )
    op.create_index("ix_payments_booking_id", "payments", ["booking_id"])
    op.create_index("ix_payments_rec_status", "payments", ["reconciliation_status"])

    op.create_table(
        "refunds",
        sa.Column("id", UUID, primary_key=True),
        sa.Column(
            "payment_id", UUID, sa.ForeignKey("payments.id", ondelete="RESTRICT"), nullable=False
        ),
        sa.Column(
            "booking_id", UUID, sa.ForeignKey("bookings.id", ondelete="RESTRICT"), nullable=False
        ),
        sa.Column("amount_minor", sa.BigInteger, nullable=False),
        sa.Column("currency", sa.String(3), server_default="USD", nullable=False),
        sa.Column("reason", sa.Text, nullable=False),
        sa.Column("status", sa.String(24), server_default="approved", nullable=False),
        sa.Column("approved_by", UUID, nullable=False),
        sa.Column("idempotency_key", sa.String(128), unique=True, nullable=False),
        sa.Column("created_at", TS, server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("amount_minor > 0", name="ck_refund_amount_positive"),
    )
    op.create_index("ix_refunds_payment_id", "refunds", ["payment_id"])
    op.create_index("ix_refunds_booking_id", "refunds", ["booking_id"])

    op.create_table(
        "expenses",
        sa.Column("id", UUID, primary_key=True),
        sa.Column(
            "booking_id", UUID, sa.ForeignKey("bookings.id", ondelete="SET NULL"), nullable=True
        ),
        sa.Column(
            "vehicle_id", UUID, sa.ForeignKey("vehicles.id", ondelete="SET NULL"), nullable=True
        ),
        sa.Column(
            "driver_id",
            UUID,
            sa.ForeignKey("driver_profiles.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("submitted_by", UUID, nullable=False),
        sa.Column("category", sa.String(32), nullable=False),
        sa.Column("amount_minor", sa.BigInteger, nullable=False),
        sa.Column("currency", sa.String(3), server_default="USD", nullable=False),
        sa.Column("incurred_at", TS, nullable=False),
        sa.Column("description", sa.Text, nullable=False),
        sa.Column("receipt_key", sa.String(255), nullable=True),
        sa.Column("status", sa.String(24), server_default="pending", nullable=False),
        sa.Column("reviewed_by", UUID, nullable=True),
        sa.Column("review_notes", sa.Text, nullable=True),
        sa.Column("reviewed_at", TS, nullable=True),
        sa.Column("created_at", TS, server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", TS, server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("amount_minor > 0", name="ck_expense_amount_positive"),
    )
    op.create_index("ix_expenses_submitted_by", "expenses", ["submitted_by"])
    op.create_index("ix_expenses_status", "expenses", ["status"])


def downgrade() -> None:
    """Drop Phase 4 financial ledger tables."""
    op.drop_table("expenses")
    op.drop_table("refunds")
    op.drop_table("payments")
    op.drop_table("invoices")
