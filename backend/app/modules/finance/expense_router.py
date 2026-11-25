"""FastAPI router for trip and fleet operating expense workflows."""

from uuid import UUID

from fastapi import APIRouter, Depends, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.session import get_db_session
from app.modules.authentication.dependencies import (
    CurrentActor,
    get_current_actor,
    require_roles,
)
from app.modules.finance.expense_service import ExpenseService
from app.modules.finance.schemas import (
    ExpenseCreateRequest,
    ExpenseDecisionRequest,
    ExpenseResponse,
)

expense_router = APIRouter(prefix="/finance/expenses", tags=["Finance & Accounting"])


@expense_router.post("", response_model=ExpenseResponse, status_code=status.HTTP_201_CREATED)
async def submit_expense(
    payload: ExpenseCreateRequest,
    request: Request,
    actor: CurrentActor = Depends(get_current_actor),
    session: AsyncSession = Depends(get_db_session),
) -> ExpenseResponse:
    """Submit a trip or fleet operating expense."""
    return await ExpenseService(session).submit_expense(
        payload, actor=actor, correlation_id=getattr(request.state, "correlation_id", None)
    )


@expense_router.get("", response_model=list[ExpenseResponse])
async def list_expenses(
    actor: CurrentActor = Depends(get_current_actor),
    session: AsyncSession = Depends(get_db_session),
) -> list[ExpenseResponse]:
    """List expenses (staff sees all; drivers see own submitted expenses)."""
    return await ExpenseService(session).list_expenses(actor)


@expense_router.post("/{expense_id}/decision", response_model=ExpenseResponse)
async def decide_expense(
    expense_id: UUID,
    payload: ExpenseDecisionRequest,
    request: Request,
    actor: CurrentActor = Depends(require_roles("accountant", "owner")),
    session: AsyncSession = Depends(get_db_session),
) -> ExpenseResponse:
    """Approve or reject a submitted expense (`accountant` or `owner` only)."""
    return await ExpenseService(session).decide_expense(
        expense_id,
        payload,
        actor=actor,
        correlation_id=getattr(request.state, "correlation_id", None),
    )
