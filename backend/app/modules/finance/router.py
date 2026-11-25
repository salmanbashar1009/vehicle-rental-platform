"""FastAPI router for payments, refunds, invoices, PDFs, and financial summaries."""

from uuid import UUID

from fastapi import APIRouter, Depends, Header, Request, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.idempotency import parse_idempotency_key
from app.database.session import get_db_session
from app.modules.authentication.dependencies import (
    CurrentActor,
    get_current_actor,
    require_permissions,
    require_roles,
)
from app.modules.finance.invoice_expense_service import InvoiceService
from app.modules.finance.ledger_service import FinanceLedgerService
from app.modules.finance.refund_service import RefundService
from app.modules.finance.schemas import (
    BookingFinancialSummary,
    InvoiceCreateRequest,
    InvoiceResponse,
    PaymentCreateRequest,
    PaymentReconcileRequest,
    PaymentResponse,
    PeriodFinanceSummary,
    RefundCreateRequest,
    RefundResponse,
)
from app.modules.finance.summary_service import PeriodSummaryService

router = APIRouter(prefix="/finance", tags=["Finance & Accounting"])


@router.get("/summary", response_model=PeriodFinanceSummary)
async def get_period_finance_summary(
    currency: str = "USD",
    _actor: CurrentActor = Depends(require_permissions("finance.read")),
    session: AsyncSession = Depends(get_db_session),
) -> PeriodFinanceSummary:
    """Return company-wide cash flow vs recognized revenue & expense reconciliation."""
    return await PeriodSummaryService(session).get_period_summary(currency=currency)


@router.get("/bookings/{booking_id}/summary", response_model=BookingFinancialSummary)
async def get_booking_finance_summary(
    booking_id: UUID,
    actor: CurrentActor = Depends(get_current_actor),
    session: AsyncSession = Depends(get_db_session),
) -> BookingFinancialSummary:
    """Return booking cash flow vs recognized agreed value (`FIN-003`)."""
    return await FinanceLedgerService(session).get_booking_financial_summary(booking_id, actor)


@router.get("/bookings/{booking_id}/payments", response_model=list[PaymentResponse])
async def list_booking_payments(
    booking_id: UUID,
    actor: CurrentActor = Depends(get_current_actor),
    session: AsyncSession = Depends(get_db_session),
) -> list[PaymentResponse]:
    """List booking payment ledger rows (finance staff or booking owner)."""
    return await FinanceLedgerService(session).list_booking_payments(booking_id, actor)


@router.post("/payments", response_model=PaymentResponse, status_code=status.HTTP_201_CREATED)
async def record_payment(
    payload: PaymentCreateRequest,
    request: Request,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    actor: CurrentActor = Depends(get_current_actor),
    session: AsyncSession = Depends(get_db_session),
) -> PaymentResponse:
    """Record idempotent payment (finance.write staff or booking-owning customer)."""
    valid_key = parse_idempotency_key(idempotency_key)
    return await FinanceLedgerService(session).record_payment(
        payload,
        actor=actor,
        idempotency_key=valid_key,
        correlation_id=getattr(request.state, "correlation_id", None),
    )


@router.patch("/payments/{payment_id}/reconcile", response_model=PaymentResponse)
async def reconcile_payment(
    payment_id: UUID,
    payload: PaymentReconcileRequest,
    request: Request,
    actor: CurrentActor = Depends(require_permissions("finance.write")),
    session: AsyncSession = Depends(get_db_session),
) -> PaymentResponse:
    """Reconcile or dispute a payment without mutating immutable amount/currency."""
    return await FinanceLedgerService(session).reconcile_payment(
        payment_id,
        payload,
        actor=actor,
        correlation_id=getattr(request.state, "correlation_id", None),
    )


@router.post("/refunds", response_model=RefundResponse, status_code=status.HTTP_201_CREATED)
async def issue_refund(
    payload: RefundCreateRequest,
    request: Request,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    actor: CurrentActor = Depends(require_roles("accountant", "owner")),
    session: AsyncSession = Depends(get_db_session),
) -> RefundResponse:
    """Issue refund strictly linked to original payment (`accountant` or `owner` only)."""
    valid_key = parse_idempotency_key(idempotency_key)
    return await RefundService(session).issue_refund(
        payload,
        actor=actor,
        idempotency_key=valid_key,
        correlation_id=getattr(request.state, "correlation_id", None),
    )


@router.post(
    "/bookings/{booking_id}/invoices",
    response_model=InvoiceResponse,
    status_code=status.HTTP_201_CREATED,
)
async def generate_invoice(
    booking_id: UUID,
    payload: InvoiceCreateRequest,
    request: Request,
    actor: CurrentActor = Depends(require_permissions("finance.write")),
    session: AsyncSession = Depends(get_db_session),
) -> InvoiceResponse:
    """Generate sequential invoice with line items and integer totals."""
    return await InvoiceService(session).generate_invoice(
        booking_id,
        payload,
        actor=actor,
        correlation_id=getattr(request.state, "correlation_id", None),
    )


@router.get("/bookings/{booking_id}/invoices", response_model=list[InvoiceResponse])
async def list_booking_invoices(
    booking_id: UUID,
    actor: CurrentActor = Depends(get_current_actor),
    session: AsyncSession = Depends(get_db_session),
) -> list[InvoiceResponse]:
    """List invoices on a booking (finance staff or owning customer)."""
    return await InvoiceService(session).list_booking_invoices(booking_id, actor)


@router.get("/invoices/{invoice_id}/pdf")
async def download_invoice_pdf(
    invoice_id: UUID,
    actor: CurrentActor = Depends(get_current_actor),
    session: AsyncSession = Depends(get_db_session),
) -> Response:
    """Download sequential invoice PDF document."""
    filename, pdf_bytes = await InvoiceService(session).render_invoice_pdf(invoice_id, actor)
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
