"""FastAPI router for customer self-service profile endpoints."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.session import get_db_session
from app.modules.authentication.dependencies import CurrentActor, require_roles
from app.modules.customers.schemas import (
    CustomerProfileResponse,
    CustomerProfileUpdateRequest,
)
from app.modules.customers.service import CustomerService

router = APIRouter(prefix="/customers", tags=["Customers"])


@router.get("/me", response_model=CustomerProfileResponse)
async def get_my_customer_profile(
    actor: CurrentActor = Depends(require_roles("customer")),
    session: AsyncSession = Depends(get_db_session),
) -> CustomerProfileResponse:
    """Get authenticated customer's profile."""
    return await CustomerService(session).get_my_profile(actor)


@router.patch("/me", response_model=CustomerProfileResponse)
async def update_my_customer_profile(
    payload: CustomerProfileUpdateRequest,
    actor: CurrentActor = Depends(require_roles("customer")),
    session: AsyncSession = Depends(get_db_session),
) -> CustomerProfileResponse:
    """Update authenticated customer's own profile."""
    return await CustomerService(session).update_my_profile(actor, payload)
