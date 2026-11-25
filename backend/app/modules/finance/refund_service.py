"""Refund approval ledger service (`accountant` / `owner` only)."""

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, NotFoundError, ValidationDomainError
from app.modules.audit.service import AuditService
from app.modules.authentication.dependencies import CurrentActor
from app.modules.finance.models import Payment, Refund
from app.modules.finance.schemas import RefundCreateRequest, RefundResponse


class RefundService:
    """Appends immutable refunds verified against original payment amount."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def issue_refund(
        self,
        payload: RefundCreateRequest,
        *,
        actor: CurrentActor,
        idempotency_key: str,
        correlation_id: str | None,
    ) -> RefundResponse:
        """Approve and append refund linked to original payment (`accountant`/`owner` only)."""
        existing = (
            await self._session.execute(
                select(Refund).where(Refund.idempotency_key == idempotency_key)
            )
        ).scalar_one_or_none()
        if existing is not None:
            if (
                existing.payment_id != payload.payment_id
                or existing.amount_minor != payload.amount_minor
            ):
                raise ConflictError("Idempotency-Key reused with different refund payload.")
            return RefundResponse.model_validate(existing)

        payment = (
            await self._session.execute(
                select(Payment).where(Payment.id == payload.payment_id).with_for_update()
            )
        ).scalar_one_or_none()
        if payment is None:
            raise NotFoundError("Original payment not found.")

        already_refunded = int(
            (
                await self._session.execute(
                    select(func.coalesce(func.sum(Refund.amount_minor), 0)).where(
                        Refund.payment_id == payment.id
                    )
                )
            ).scalar_one()
            or 0
        )
        if already_refunded + payload.amount_minor > payment.amount_minor:
            raise ValidationDomainError("Refund exceeds remaining refundable payment amount.")

        refund = Refund(
            payment_id=payment.id,
            booking_id=payment.booking_id,
            amount_minor=payload.amount_minor,
            currency=payment.currency,
            reason=payload.reason,
            status="approved",
            approved_by=actor.user_id,
            idempotency_key=idempotency_key,
        )
        self._session.add(refund)
        await self._session.flush()

        AuditService.record(
            self._session,
            actor_id=actor.user_id,
            actor_role=actor.primary_role,
            action="finance.refund_issued",
            resource_type="refund",
            resource_id=str(refund.id),
            before_state={"already_refunded_minor": already_refunded},
            after_state={
                "refunded_minor": already_refunded + refund.amount_minor,
                "payment_id": str(payment.id),
            },
            reason=payload.reason,
            correlation_id=correlation_id,
        )
        await self._session.commit()
        await self._session.refresh(refund)
        return RefundResponse.model_validate(refund)
