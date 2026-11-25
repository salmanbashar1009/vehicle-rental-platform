"""Trip and fleet operating expense submission and approval service."""

from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ForbiddenError, NotFoundError, ValidationDomainError
from app.modules.audit.service import AuditService
from app.modules.authentication.dependencies import CurrentActor
from app.modules.dispatch.models import Assignment
from app.modules.drivers.models import DriverProfile
from app.modules.finance.models import Expense
from app.modules.finance.schemas import (
    ExpenseCreateRequest,
    ExpenseDecisionRequest,
    ExpenseResponse,
)


class ExpenseService:
    """Manages trip/fleet expense submission and accountant/owner decisions."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def submit_expense(
        self, payload: ExpenseCreateRequest, *, actor: CurrentActor, correlation_id: str | None
    ) -> ExpenseResponse:
        """Allow drivers (on own booking) or finance/fleet staff to submit expenses."""
        driver_id: UUID | None = None
        is_staff = actor.has_permission("finance.write") or actor.has_permission("fleet.write")
        if not is_staff:
            if "driver" not in actor.roles:
                raise ForbiddenError("Not authorized to submit expenses.")
            drv = (
                await self._session.execute(
                    select(DriverProfile).where(DriverProfile.user_id == actor.user_id)
                )
            ).scalar_one_or_none()
            if drv is None or payload.booking_id is None:
                raise ForbiddenError("Drivers must submit expenses linked to an assigned booking.")
            owned_assign = (
                await self._session.execute(
                    select(Assignment).where(
                        Assignment.booking_id == payload.booking_id,
                        Assignment.driver_id == drv.id,
                    )
                )
            ).scalar_one_or_none()
            if owned_assign is None:
                raise ForbiddenError("You can only log expenses against your own assigned trips.")
            driver_id = drv.id

        expense = Expense(
            booking_id=payload.booking_id,
            vehicle_id=payload.vehicle_id,
            driver_id=driver_id,
            submitted_by=actor.user_id,
            category=payload.category,
            amount_minor=payload.amount_minor,
            currency=payload.currency.upper(),
            incurred_at=payload.incurred_at,
            description=payload.description,
            receipt_key=payload.receipt_key,
            status="pending",
        )
        self._session.add(expense)
        await self._session.flush()
        AuditService.record(
            self._session,
            actor_id=actor.user_id,
            actor_role=actor.primary_role,
            action="finance.expense_submitted",
            resource_type="expense",
            resource_id=str(expense.id),
            after_state={"category": expense.category, "amount_minor": expense.amount_minor},
            correlation_id=correlation_id,
        )
        await self._session.commit()
        await self._session.refresh(expense)
        return ExpenseResponse.model_validate(expense)

    async def decide_expense(
        self,
        expense_id: UUID,
        payload: ExpenseDecisionRequest,
        *,
        actor: CurrentActor,
        correlation_id: str | None,
    ) -> ExpenseResponse:
        """Accountant/Owner approves or rejects a pending expense."""
        exp = (
            await self._session.execute(
                select(Expense).where(Expense.id == expense_id).with_for_update()
            )
        ).scalar_one_or_none()
        if exp is None:
            raise NotFoundError("Expense not found.")
        if exp.status != "pending":
            raise ValidationDomainError(f"Expense already '{exp.status}'.")

        exp.status = payload.status
        exp.review_notes = payload.review_notes
        exp.reviewed_by = actor.user_id
        exp.reviewed_at = datetime.now(UTC)
        AuditService.record(
            self._session,
            actor_id=actor.user_id,
            actor_role=actor.primary_role,
            action=f"finance.expense_{payload.status}",
            resource_type="expense",
            resource_id=str(exp.id),
            before_state={"status": "pending"},
            after_state={"status": exp.status},
            reason=payload.review_notes,
            correlation_id=correlation_id,
        )
        await self._session.commit()
        await self._session.refresh(exp)
        return ExpenseResponse.model_validate(exp)

    async def list_expenses(self, actor: CurrentActor) -> list[ExpenseResponse]:
        """List expenses filtered by staff permissions or driver ownership."""
        stmt = select(Expense).order_by(Expense.created_at.desc())
        if not actor.has_permission("finance.read"):
            stmt = stmt.where(Expense.submitted_by == actor.user_id)
        rows = (await self._session.execute(stmt)).scalars().all()
        return [ExpenseResponse.model_validate(r) for r in rows]
