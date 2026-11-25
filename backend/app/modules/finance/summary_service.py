"""Company-wide cash-flow vs recognized-revenue and expense reconciliation summary."""

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.bookings.models import Booking
from app.modules.finance.helpers import compute_booking_summary
from app.modules.finance.models import Expense, Payment, Refund
from app.modules.finance.schemas import PeriodFinanceSummary


class PeriodSummaryService:
    """Computes recognized revenue vs cash flow across active and closed bookings."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_period_summary(self, currency: str = "USD") -> PeriodFinanceSummary:
        """Return cash-flow vs recognized-revenue + expenses dashboard reconciliation."""
        cur = currency.upper()
        collected = int(
            (
                await self._session.execute(
                    select(func.coalesce(func.sum(Payment.amount_minor), 0)).where(
                        Payment.currency == cur, Payment.reconciliation_status == "reconciled"
                    )
                )
            ).scalar_one()
            or 0
        )
        pending = int(
            (
                await self._session.execute(
                    select(func.coalesce(func.sum(Payment.amount_minor), 0)).where(
                        Payment.currency == cur, Payment.reconciliation_status == "pending"
                    )
                )
            ).scalar_one()
            or 0
        )
        refunded = int(
            (
                await self._session.execute(
                    select(func.coalesce(func.sum(Refund.amount_minor), 0)).where(
                        Refund.currency == cur
                    )
                )
            ).scalar_one()
            or 0
        )
        expenses = int(
            (
                await self._session.execute(
                    select(func.coalesce(func.sum(Expense.amount_minor), 0)).where(
                        Expense.currency == cur, Expense.status == "approved"
                    )
                )
            ).scalar_one()
            or 0
        )
        bookings = (
            (
                await self._session.execute(
                    select(Booking).where(
                        Booking.deleted_at.is_(None),
                        Booking.status.in_(
                            ("confirmed", "assigned", "in_progress", "completed", "closed")
                        ),
                    )
                )
            )
            .scalars()
            .all()
        )
        recognized = 0
        for b in bookings:
            s = await compute_booking_summary(self._session, b)
            if s.currency == cur:
                recognized += s.recognized_total_minor

        return PeriodFinanceSummary(
            currency=cur,
            recognized_revenue_minor=recognized,
            cash_collected_minor=collected,
            pending_collections_minor=pending,
            refunded_minor=refunded,
            approved_expenses_minor=expenses,
            net_cash_flow_minor=collected - refunded - expenses,
        )
