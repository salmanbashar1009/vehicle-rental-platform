"""Customer CRM profile linking and communication logs service."""

from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NotFoundError
from app.modules.authentication.dependencies import CurrentActor
from app.modules.bookings.models import Booking
from app.modules.crm.models import CustomerCommsLog
from app.modules.crm.schemas import (
    CrmCustomerSummary,
    CustomerCommsCreateRequest,
    CustomerCommsResponse,
    CustomerLinkCorporateRequest,
)
from app.modules.customers.models import CustomerProfile


class CustomerCrmService:
    """Manages CRM customer list, corporate linking, and communication logs."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def list_customers(self) -> list[CrmCustomerSummary]:
        """List CRM customer profiles with total non-deleted booking counts."""
        customers = (
            (
                await self._session.execute(
                    select(CustomerProfile)
                    .where(CustomerProfile.deleted_at.is_(None))
                    .order_by(CustomerProfile.created_at.desc())
                )
            )
            .scalars()
            .all()
        )
        counts_raw = (
            await self._session.execute(
                select(Booking.customer_id, func.count(Booking.id))
                .where(Booking.deleted_at.is_(None))
                .group_by(Booking.customer_id)
            )
        ).all()
        counts = {cid: int(cnt) for cid, cnt in counts_raw}
        return [
            CrmCustomerSummary(
                id=c.id,
                full_name=c.full_name,
                email=c.email,
                phone=c.phone,
                customer_type=c.customer_type,
                corporate_id=c.corporate_id,
                total_bookings=counts.get(c.id, 0),
                notes=c.notes,
            )
            for c in customers
        ]

    async def link_customer_corporate(
        self, customer_id: UUID, payload: CustomerLinkCorporateRequest
    ) -> CrmCustomerSummary:
        """Link or unlink customer profile to a corporate account and save notes."""
        c = (
            await self._session.execute(
                select(CustomerProfile).where(CustomerProfile.id == customer_id)
            )
        ).scalar_one_or_none()
        if c is None:
            raise NotFoundError("Customer profile not found.")
        c.corporate_id = payload.corporate_id
        c.customer_type = "corporate" if payload.corporate_id else "individual"
        if payload.notes is not None:
            c.notes = payload.notes
        await self._session.commit()
        total = int(
            (
                await self._session.execute(
                    select(func.count(Booking.id)).where(
                        Booking.customer_id == c.id, Booking.deleted_at.is_(None)
                    )
                )
            ).scalar_one()
            or 0
        )
        return CrmCustomerSummary(
            id=c.id,
            full_name=c.full_name,
            email=c.email,
            phone=c.phone,
            customer_type=c.customer_type,
            corporate_id=c.corporate_id,
            total_bookings=total,
            notes=c.notes,
        )

    async def add_comm_log(
        self, customer_id: UUID, payload: CustomerCommsCreateRequest, *, actor: CurrentActor
    ) -> CustomerCommsResponse:
        """Append CRM communication note (`call`, `email`, `whatsapp`, `note`)."""
        c = (
            await self._session.execute(
                select(CustomerProfile).where(CustomerProfile.id == customer_id)
            )
        ).scalar_one_or_none()
        if c is None:
            raise NotFoundError("Customer not found.")
        entry = CustomerCommsLog(
            customer_id=customer_id,
            channel=payload.channel,
            summary=payload.summary,
            logged_by=actor.user_id,
        )
        self._session.add(entry)
        await self._session.commit()
        await self._session.refresh(entry)
        return CustomerCommsResponse.model_validate(entry)

    async def list_comm_logs(self, customer_id: UUID) -> list[CustomerCommsResponse]:
        """List chronological communication logs for a customer."""
        rows = (
            (
                await self._session.execute(
                    select(CustomerCommsLog)
                    .where(CustomerCommsLog.customer_id == customer_id)
                    .order_by(CustomerCommsLog.created_at.desc())
                )
            )
            .scalars()
            .all()
        )
        return [CustomerCommsResponse.model_validate(r) for r in rows]
