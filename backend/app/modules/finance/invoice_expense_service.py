"""Sequential invoice generation and PDF receipt rendering service."""

from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NotFoundError
from app.modules.audit.service import AuditService
from app.modules.authentication.dependencies import CurrentActor
from app.modules.customers.models import CustomerProfile
from app.modules.finance.helpers import compute_booking_summary, load_booking_with_finance_acl
from app.modules.finance.models import Invoice
from app.modules.finance.pdf_generator import build_invoice_pdf_bytes
from app.modules.finance.schemas import InvoiceCreateRequest, InvoiceResponse


class InvoiceService:
    """Manages sequential invoices and PDF document generation."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def generate_invoice(
        self,
        booking_id: UUID,
        payload: InvoiceCreateRequest,
        *,
        actor: CurrentActor,
        correlation_id: str | None,
    ) -> InvoiceResponse:
        """Issue sequential tax invoice for a booking using integer minor math."""
        booking = await load_booking_with_finance_acl(
            self._session, booking_id, actor, require_staff=True
        )
        summary = await compute_booking_summary(self._session, booking)
        discount = payload.discount_minor or summary.discount_minor
        total = max(
            summary.agreed_minor + summary.extra_charges_minor - discount + payload.tax_minor, 0
        )
        seq = (
            int((await self._session.execute(select(func.count(Invoice.id)))).scalar_one() or 0) + 1
        )
        year = datetime.now(UTC).year
        inv_num = f"INV-{year}-{seq:06d}"

        items = [
            {"label": "Agreed Service Charge", "amount_minor": summary.agreed_minor},
            {"label": "Extra & Waiting Charges", "amount_minor": summary.extra_charges_minor},
            {"label": "Discount", "amount_minor": -discount},
            {"label": "Tax", "amount_minor": payload.tax_minor},
        ]
        status_val = (
            "paid"
            if summary.paid_minor >= total and total > 0
            else ("partially_paid" if summary.paid_minor > 0 else "issued")
        )
        invoice = Invoice(
            booking_id=booking.id,
            invoice_number=inv_num,
            agreed_minor=summary.agreed_minor,
            extra_minor=summary.extra_charges_minor,
            discount_minor=discount,
            tax_minor=payload.tax_minor,
            total_minor=total,
            currency=summary.currency,
            line_items_json=items,
            status=status_val,
        )
        self._session.add(invoice)
        await self._session.flush()
        AuditService.record(
            self._session,
            actor_id=actor.user_id,
            actor_role=actor.primary_role,
            action="finance.invoice_issued",
            resource_type="invoice",
            resource_id=str(invoice.id),
            after_state={"invoice_number": inv_num, "total_minor": total},
            correlation_id=correlation_id,
        )
        await self._session.commit()
        await self._session.refresh(invoice)
        return InvoiceResponse.model_validate(invoice)

    async def list_booking_invoices(
        self, booking_id: UUID, actor: CurrentActor
    ) -> list[InvoiceResponse]:
        """List invoices issued for a booking (staff or booking owner)."""
        await load_booking_with_finance_acl(self._session, booking_id, actor)
        rows = (
            (
                await self._session.execute(
                    select(Invoice)
                    .where(Invoice.booking_id == booking_id)
                    .order_by(Invoice.issued_at.desc())
                )
            )
            .scalars()
            .all()
        )
        return [InvoiceResponse.model_validate(r) for r in rows]

    async def render_invoice_pdf(self, invoice_id: UUID, actor: CurrentActor) -> tuple[str, bytes]:
        """Authorize access and build valid PDF invoice document."""
        inv = (
            await self._session.execute(select(Invoice).where(Invoice.id == invoice_id))
        ).scalar_one_or_none()
        if inv is None:
            raise NotFoundError("Invoice not found.")
        booking = await load_booking_with_finance_acl(self._session, inv.booking_id, actor)
        cust = (
            await self._session.execute(
                select(CustomerProfile).where(CustomerProfile.id == booking.customer_id)
            )
        ).scalar_one()
        pdf_bytes = build_invoice_pdf_bytes(
            invoice_number=inv.invoice_number,
            booking_reference=booking.reference,
            customer_name=cust.full_name,
            issued_at_iso=inv.issued_at.isoformat(),
            currency=inv.currency,
            agreed_minor=inv.agreed_minor,
            extra_minor=inv.extra_minor,
            discount_minor=inv.discount_minor,
            tax_minor=inv.tax_minor,
            total_minor=inv.total_minor,
            status=inv.status,
        )
        return f"{inv.invoice_number}.pdf", pdf_bytes
