"""Immutable payment and reconciliation ledger service."""

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError
from app.modules.audit.service import AuditService
from app.modules.authentication.dependencies import CurrentActor
from app.modules.bookings.models import Booking
from app.modules.customers.models import CustomerProfile
from app.modules.finance.helpers import (
    compute_booking_summary,
    load_booking_with_finance_acl,
    sync_invoice_statuses,
)
from app.modules.finance.models import Payment
from app.modules.finance.schemas import (
    BookingFinancialSummary,
    PaymentCreateRequest,
    PaymentReconcileRequest,
    PaymentResponse,
)
from app.modules.notifications.service import NotificationService


class FinanceLedgerService:
    """Handles idempotent payment recording and reconciliation status updates."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def record_payment(
        self,
        payload: PaymentCreateRequest,
        *,
        actor: CurrentActor,
        idempotency_key: str,
        correlation_id: str | None,
    ) -> PaymentResponse:
        """Append immutable payment record idempotently (`FIN-002`)."""
        existing = (
            await self._session.execute(
                select(Payment).where(Payment.idempotency_key == idempotency_key)
            )
        ).scalar_one_or_none()
        if existing is not None:
            if (
                existing.booking_id != payload.booking_id
                or existing.amount_minor != payload.amount_minor
            ):
                raise ConflictError("Idempotency-Key reused with different payment payload.")
            return PaymentResponse.model_validate(existing)

        booking = await load_booking_with_finance_acl(self._session, payload.booking_id, actor)
        is_staff = actor.has_permission("finance.write")
        rec_status = payload.reconciliation_status or ("reconciled" if is_staff else "pending")
        if not is_staff and rec_status != "pending":
            raise ForbiddenError("Only finance staff can record pre-reconciled payments.")

        payment = Payment(
            booking_id=booking.id,
            invoice_id=payload.invoice_id,
            payment_type=payload.payment_type,
            method=payload.method,
            amount_minor=payload.amount_minor,
            currency=payload.currency.upper(),
            transaction_ref=payload.transaction_ref,
            reconciliation_status=rec_status,
            idempotency_key=idempotency_key,
            recorded_by=actor.user_id,
            notes=payload.notes,
        )
        self._session.add(payment)
        await self._session.flush()

        summary = await compute_booking_summary(self._session, booking)
        await sync_invoice_statuses(self._session, booking.id, summary.paid_minor)

        cust = (
            await self._session.execute(
                select(CustomerProfile).where(CustomerProfile.id == booking.customer_id)
            )
        ).scalar_one()
        if cust.user_id is not None:
            await NotificationService.enqueue(
                self._session,
                user_id=cust.user_id,
                event_type="payment.received",
                title=f"Payment recorded for {booking.reference}",
                body=f"{payment.currency} {payment.amount_minor / 100:.2f} ({payment.method})",
                dedup_key=f"payment:{payment.id}",
                resource_type="booking",
                resource_id=str(booking.id),
            )

        AuditService.record(
            self._session,
            actor_id=actor.user_id,
            actor_role=actor.primary_role,
            action="finance.payment_recorded",
            resource_type="payment",
            resource_id=str(payment.id),
            after_state={
                "booking_id": str(booking.id),
                "amount_minor": payment.amount_minor,
                "currency": payment.currency,
                "reconciliation_status": payment.reconciliation_status,
            },
            correlation_id=correlation_id,
        )
        await self._session.commit()
        await self._session.refresh(payment)
        return PaymentResponse.model_validate(payment)

    async def reconcile_payment(
        self,
        payment_id: UUID,
        payload: PaymentReconcileRequest,
        *,
        actor: CurrentActor,
        correlation_id: str | None,
    ) -> PaymentResponse:
        """Transition payment reconciliation status without mutating amount or currency."""
        payment = (
            await self._session.execute(
                select(Payment).where(Payment.id == payment_id).with_for_update()
            )
        ).scalar_one_or_none()
        if payment is None:
            raise NotFoundError("Payment not found.")

        before = {"reconciliation_status": payment.reconciliation_status}
        payment.reconciliation_status = payload.reconciliation_status
        if payload.notes:
            payment.notes = payload.notes
        await self._session.flush()

        booking = (
            await self._session.execute(select(Booking).where(Booking.id == payment.booking_id))
        ).scalar_one()
        summary = await compute_booking_summary(self._session, booking)
        await sync_invoice_statuses(self._session, booking.id, summary.paid_minor)

        AuditService.record(
            self._session,
            actor_id=actor.user_id,
            actor_role=actor.primary_role,
            action="finance.payment_reconciled",
            resource_type="payment",
            resource_id=str(payment.id),
            before_state=before,
            after_state={"reconciliation_status": payment.reconciliation_status},
            reason=payload.notes,
            correlation_id=correlation_id,
        )
        await self._session.commit()
        await self._session.refresh(payment)
        return PaymentResponse.model_validate(payment)

    async def list_booking_payments(
        self, booking_id: UUID, actor: CurrentActor
    ) -> list[PaymentResponse]:
        """List payments on a booking enforcing staff RBAC or customer ownership."""
        await load_booking_with_finance_acl(self._session, booking_id, actor)
        rows = (
            (
                await self._session.execute(
                    select(Payment)
                    .where(Payment.booking_id == booking_id)
                    .order_by(Payment.created_at.desc())
                )
            )
            .scalars()
            .all()
        )
        return [PaymentResponse.model_validate(r) for r in rows]

    async def get_booking_financial_summary(
        self, booking_id: UUID, actor: CurrentActor
    ) -> BookingFinancialSummary:
        """Return booking financial breakdown cleanly separating cash flow and agreed value."""
        booking = await load_booking_with_finance_acl(self._session, booking_id, actor)
        return await compute_booking_summary(self._session, booking)
