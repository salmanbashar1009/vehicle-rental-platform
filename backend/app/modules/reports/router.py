"""FastAPI routers for operational reports, exports, and dispatch recommendations."""

from uuid import UUID

from fastapi import APIRouter, Depends, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.session import get_db_session
from app.modules.authentication.dependencies import CurrentActor, require_permissions
from app.modules.reports.recommendation_service import DispatchRecommendationService
from app.modules.reports.schemas import (
    DispatchRecommendationsResponse,
    OperationsReportResponse,
)
from app.modules.reports.service import ReportsService

router = APIRouter(prefix="/reports", tags=["Reports & Analytics"])
dispatch_rec_router = APIRouter(prefix="/dispatch", tags=["Dispatch"])


@router.get("/operations", response_model=OperationsReportResponse)
async def get_operations_report(
    _actor: CurrentActor = Depends(require_permissions("reports.read")),
    session: AsyncSession = Depends(get_db_session),
) -> OperationsReportResponse:
    """View fleet utilization, cancellation rate, driver performance, and service popularity."""
    return await ReportsService(session).get_operations_report()


@router.get("/export")
async def export_operations_report(
    export_format: str = "csv",
    _actor: CurrentActor = Depends(require_permissions("reports.read")),
    session: AsyncSession = Depends(get_db_session),
) -> Response:
    """Export operational report as CSV (`text/csv`) or PDF (`application/pdf`)."""
    svc = ReportsService(session)
    if export_format.lower() == "pdf":
        data = await svc.export_pdf()
        return Response(
            content=data,
            media_type="application/pdf",
            headers={"Content-Disposition": 'attachment; filename="velofleet-ops-report.pdf"'},
        )
    data = await svc.export_csv()
    return Response(
        content=data,
        media_type="text/csv",
        headers={"Content-Disposition": 'attachment; filename="velofleet-ops-report.csv"'},
    )


@dispatch_rec_router.get("/recommendations", response_model=DispatchRecommendationsResponse)
async def get_dispatch_recommendations(
    booking_id: UUID,
    _actor: CurrentActor = Depends(require_permissions("dispatch.read")),
    session: AsyncSession = Depends(get_db_session),
) -> DispatchRecommendationsResponse:
    """Rank eligible vehicles and drivers for dispatch selection."""
    return await DispatchRecommendationService(session).recommend_for_booking(booking_id)
