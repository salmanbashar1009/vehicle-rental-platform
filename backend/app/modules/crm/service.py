"""Corporate B2B account creation, updates, and balance reconciliation."""

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NotFoundError
from app.modules.audit.service import AuditService
from app.modules.authentication.dependencies import CurrentActor
from app.modules.bookings.models import Booking
from app.modules.crm.schemas import (
    CorporateAccountCreateRequest,
    CorporateAccountResponse,
    CorporateAccountUpdateRequest,
    CorporateBalanceResponse,
)
from app.modules.customers.models import CorporateAccount, CustomerProfile
from app.modules.finance.helpers import compute_booking_summary


class CrmService:
    """Handles B2B corporate accounts and outstanding balance computations."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create_corporate(
        self,
        payload: CorporateAccountCreateRequest,
        *,
        actor: CurrentActor,
        correlation_id: str | None,
    ) -> CorporateAccountResponse:
        """Create a new B2B corporate client account."""
        acct = CorporateAccount(
            company_name=payload.company_name,
            tax_id=payload.tax_id,
            billing_cycle=payload.billing_cycle,
            credit_limit_minor=payload.credit_limit_minor,
            currency=payload.currency.upper(),
            negotiated_discount_bps=payload.negotiated_discount_bps,
        )
        self._session.add(acct)
        await self._session.flush()
        AuditService.record(
            self._session,
            actor_id=actor.user_id,
            actor_role=actor.primary_role,
            action="crm.corporate_created",
            resource_type="corporate_account",
            resource_id=str(acct.id),
            after_state={"company_name": acct.company_name},
            correlation_id=correlation_id,
        )
        await self._session.commit()
        await self._session.refresh(acct)
        return CorporateAccountResponse.model_validate(acct)

    async def list_corporate(self) -> list[CorporateAccountResponse]:
        """List all B2B corporate accounts."""
        rows = (await self._session.execute(select(CorporateAccount))).scalars().all()
        return [CorporateAccountResponse.model_validate(r) for r in rows]

    async def update_corporate(
        self, corp_id: UUID, payload: CorporateAccountUpdateRequest
    ) -> CorporateAccountResponse:
        """Update negotiated discount or credit limit on a corporate account."""
        acct = (
            await self._session.execute(
                select(CorporateAccount).where(CorporateAccount.id == corp_id)
            )
        ).scalar_one_or_none()
        if acct is None:
            raise NotFoundError("Corporate account not found.")
        for field, val in payload.model_dump(exclude_none=True).items():
            setattr(acct, field, val)
        await self._session.commit()
        await self._session.refresh(acct)
        return CorporateAccountResponse.model_validate(acct)

    async def get_corporate_balance(self, corp_id: UUID) -> CorporateBalanceResponse:
        """Compute outstanding corporate balance across all linked customers' bookings."""
        acct = (
            await self._session.execute(
                select(CorporateAccount).where(CorporateAccount.id == corp_id)
            )
        ).scalar_one_or_none()
        if acct is None:
            raise NotFoundError("Corporate account not found.")
        cust_ids = list(
            (
                await self._session.execute(
                    select(CustomerProfile.id).where(CustomerProfile.corporate_id == corp_id)
                )
            )
            .scalars()
            .all()
        )
        bookings = (
            (
                await self._session.execute(
                    select(Booking).where(
                        Booking.customer_id.in_(cust_ids), Booking.deleted_at.is_(None)
                    )
                )
            )
            .scalars()
            .all()
            if cust_ids
            else []
        )
        recognized = 0
        paid = 0
        outstanding = 0
        for b in bookings:
            s = await compute_booking_summary(self._session, b)
            recognized += s.recognized_total_minor
            paid += s.paid_minor
            outstanding += s.outstanding_minor
        return CorporateBalanceResponse(
            corporate_id=acct.id,
            company_name=acct.company_name,
            currency=acct.currency,
            credit_limit_minor=acct.credit_limit_minor,
            recognized_total_minor=recognized,
            paid_minor=paid,
            outstanding_minor=outstanding,
            active_customers=len(cust_ids),
            total_bookings=len(bookings),
        )
