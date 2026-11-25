"""FastAPI routers for corporate accounts and CRM customer communications."""

from uuid import UUID

from fastapi import APIRouter, Depends, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.session import get_db_session
from app.modules.authentication.dependencies import CurrentActor, require_permissions
from app.modules.crm.customer_crm_service import CustomerCrmService
from app.modules.crm.schemas import (
    CorporateAccountCreateRequest,
    CorporateAccountResponse,
    CorporateAccountUpdateRequest,
    CorporateBalanceResponse,
    CrmCustomerSummary,
    CustomerCommsCreateRequest,
    CustomerCommsResponse,
    CustomerLinkCorporateRequest,
)
from app.modules.crm.service import CrmService

corporate_router = APIRouter(prefix="/corporate/accounts", tags=["Corporate & CRM"])
crm_router = APIRouter(prefix="/crm/customers", tags=["Corporate & CRM"])


@corporate_router.post(
    "", response_model=CorporateAccountResponse, status_code=status.HTTP_201_CREATED
)
async def create_corporate_account(
    payload: CorporateAccountCreateRequest,
    request: Request,
    actor: CurrentActor = Depends(require_permissions("bookings.write")),
    session: AsyncSession = Depends(get_db_session),
) -> CorporateAccountResponse:
    """Create a B2B corporate account with negotiated discount."""
    return await CrmService(session).create_corporate(
        payload, actor=actor, correlation_id=getattr(request.state, "correlation_id", None)
    )


@corporate_router.get("", response_model=list[CorporateAccountResponse])
async def list_corporate_accounts(
    _actor: CurrentActor = Depends(require_permissions("bookings.read")),
    session: AsyncSession = Depends(get_db_session),
) -> list[CorporateAccountResponse]:
    """List B2B corporate accounts."""
    return await CrmService(session).list_corporate()


@corporate_router.patch("/{corp_id}", response_model=CorporateAccountResponse)
async def update_corporate_account(
    corp_id: UUID,
    payload: CorporateAccountUpdateRequest,
    _actor: CurrentActor = Depends(require_permissions("bookings.write")),
    session: AsyncSession = Depends(get_db_session),
) -> CorporateAccountResponse:
    """Update negotiated corporate account settings."""
    return await CrmService(session).update_corporate(corp_id, payload)


@corporate_router.get("/{corp_id}/balance", response_model=CorporateBalanceResponse)
async def get_corporate_balance(
    corp_id: UUID,
    _actor: CurrentActor = Depends(require_permissions("finance.read")),
    session: AsyncSession = Depends(get_db_session),
) -> CorporateBalanceResponse:
    """View outstanding corporate balance and booking utilization."""
    return await CrmService(session).get_corporate_balance(corp_id)


@crm_router.get("", response_model=list[CrmCustomerSummary])
async def list_crm_customers(
    _actor: CurrentActor = Depends(require_permissions("bookings.read")),
    session: AsyncSession = Depends(get_db_session),
) -> list[CrmCustomerSummary]:
    """List CRM customer directory with booking counts."""
    return await CustomerCrmService(session).list_customers()


@crm_router.patch("/{customer_id}", response_model=CrmCustomerSummary)
async def link_customer_corporate(
    customer_id: UUID,
    payload: CustomerLinkCorporateRequest,
    _actor: CurrentActor = Depends(require_permissions("bookings.write")),
    session: AsyncSession = Depends(get_db_session),
) -> CrmCustomerSummary:
    """Link customer profile to a corporate account and edit CRM notes."""
    return await CustomerCrmService(session).link_customer_corporate(customer_id, payload)


@crm_router.get("/{customer_id}/comms", response_model=list[CustomerCommsResponse])
async def list_customer_comms(
    customer_id: UUID,
    _actor: CurrentActor = Depends(require_permissions("bookings.read")),
    session: AsyncSession = Depends(get_db_session),
) -> list[CustomerCommsResponse]:
    """List customer communication logs."""
    return await CustomerCrmService(session).list_comm_logs(customer_id)


@crm_router.post(
    "/{customer_id}/comms",
    response_model=CustomerCommsResponse,
    status_code=status.HTTP_201_CREATED,
)
async def add_customer_comm(
    customer_id: UUID,
    payload: CustomerCommsCreateRequest,
    actor: CurrentActor = Depends(require_permissions("bookings.read")),
    session: AsyncSession = Depends(get_db_session),
) -> CustomerCommsResponse:
    """Record customer communication note (`call`, `email`, `whatsapp`, `note`)."""
    return await CustomerCrmService(session).add_comm_log(customer_id, payload, actor=actor)
