"""Operational reporting metrics and CSV/PDF export generator."""

import csv
import io
from typing import cast

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.bookings.models import Booking
from app.modules.dispatch.models import Assignment
from app.modules.drivers.models import DriverProfile
from app.modules.finance.pdf_generator import build_invoice_pdf_bytes
from app.modules.reports.schemas import (
    DriverPerformanceItem,
    OperationsReportResponse,
    ServicePopularityItem,
)
from app.modules.reviews.models import Review
from app.modules.services.models import ServiceCategory
from app.modules.trips.models import Trip
from app.modules.vehicles.models import Vehicle


class ReportsService:
    """Computes operational KPIs and generates downloadable CSV and PDF reports."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_operations_report(self) -> OperationsReportResponse:
        """Compute utilization, cancellation rate, popularity, retention, and ratings."""
        total_b = int(
            (
                await self._session.execute(
                    select(func.count(Booking.id)).where(Booking.deleted_at.is_(None))
                )
            ).scalar_one()
            or 0
        )
        comp_b = int(
            (
                await self._session.execute(
                    select(func.count(Booking.id)).where(
                        Booking.deleted_at.is_(None), Booking.status.in_(("completed", "closed"))
                    )
                )
            ).scalar_one()
            or 0
        )
        canc_b = int(
            (
                await self._session.execute(
                    select(func.count(Booking.id)).where(
                        Booking.deleted_at.is_(None), Booking.status == "cancelled"
                    )
                )
            ).scalar_one()
            or 0
        )
        canc_rate = round((canc_b / total_b) * 100.0, 2) if total_b else 0.0

        total_v = int(
            (
                await self._session.execute(
                    select(func.count(Vehicle.id)).where(Vehicle.deleted_at.is_(None))
                )
            ).scalar_one()
            or 0
        )
        busy_v = int(
            (
                await self._session.execute(
                    select(func.count(Vehicle.id)).where(
                        Vehicle.deleted_at.is_(None),
                        Vehicle.status.in_(("reserved", "assigned", "en_route", "in_service")),
                    )
                )
            ).scalar_one()
            or 0
        )
        util_pct = round((busy_v / total_v) * 100.0, 2) if total_v else 0.0

        repeat_sub = (
            select(Booking.customer_id)
            .where(Booking.deleted_at.is_(None))
            .group_by(Booking.customer_id)
            .having(func.count(Booking.id) >= 2)
        ).subquery()
        repeat_custs = int(
            (await self._session.execute(select(func.count()).select_from(repeat_sub))).scalar_one()
            or 0
        )

        pop_rows = (
            await self._session.execute(
                select(ServiceCategory.slug, ServiceCategory.name, func.count(Booking.id))
                .join(Booking, Booking.service_category_id == ServiceCategory.id)
                .where(Booking.deleted_at.is_(None))
                .group_by(ServiceCategory.id)
                .order_by(func.count(Booking.id).desc())
            )
        ).all()
        popular = [
            ServicePopularityItem(service_slug=s, service_name=n, booking_count=int(c))
            for s, n, c in pop_rows
        ]

        drivers = (
            (
                await self._session.execute(
                    select(DriverProfile).where(DriverProfile.deleted_at.is_(None))
                )
            )
            .scalars()
            .all()
        )
        perf: list[DriverPerformanceItem] = []
        for d in drivers:
            done_cnt = int(
                (
                    await self._session.execute(
                        select(func.count(Trip.id))
                        .join(Assignment, Trip.assignment_id == Assignment.id)
                        .where(Assignment.driver_id == d.id, Trip.status == "service_completed")
                    )
                ).scalar_one()
                or 0
            )
            avg_r = cast(
                float | None,
                (
                    await self._session.execute(
                        select(func.avg(Review.driver_rating)).where(
                            Review.driver_id == d.id, Review.moderation_status == "published"
                        )
                    )
                ).scalar_one(),
            )
            perf.append(
                DriverPerformanceItem(
                    driver_id=d.id,
                    driver_name=d.user.full_name,
                    completed_trips=done_cnt,
                    average_rating=round(float(avg_r), 2) if avg_r is not None else None,
                )
            )

        return OperationsReportResponse(
            total_bookings=total_b,
            completed_bookings=comp_b,
            cancelled_bookings=canc_b,
            cancellation_rate_pct=canc_rate,
            total_vehicles=total_v,
            busy_or_active_vehicles=busy_v,
            vehicle_utilization_pct=util_pct,
            repeat_customers=repeat_custs,
            popular_services=popular,
            driver_performance=perf,
        )

    async def export_csv(self) -> bytes:
        """Export operational summary rows cleanly as UTF-8 CSV."""
        rep = await self.get_operations_report()
        buf = io.StringIO()
        writer = csv.writer(buf)
        writer.writerow(["metric", "value"])
        writer.writerow(["total_bookings", rep.total_bookings])
        writer.writerow(["completed_bookings", rep.completed_bookings])
        writer.writerow(["cancelled_bookings", rep.cancelled_bookings])
        writer.writerow(["cancellation_rate_pct", rep.cancellation_rate_pct])
        writer.writerow(["vehicle_utilization_pct", rep.vehicle_utilization_pct])
        writer.writerow(["repeat_customers", rep.repeat_customers])
        for d in rep.driver_performance:
            writer.writerow([f"driver:{d.driver_name}:completed_trips", d.completed_trips])
        return buf.getvalue().encode("utf-8")

    async def export_pdf(self) -> bytes:
        """Render concise PDF operational summary."""
        rep = await self.get_operations_report()
        return build_invoice_pdf_bytes(
            invoice_number="RPT-OPS-LATEST",
            booking_reference=f"Total={rep.total_bookings} Canc%={rep.cancellation_rate_pct}",
            customer_name=f"Utilization={rep.vehicle_utilization_pct}%",
            issued_at_iso=f"RepeatCustomers={rep.repeat_customers}",
            currency="USD",
            agreed_minor=rep.completed_bookings * 100,
            extra_minor=rep.cancelled_bookings * 100,
            discount_minor=0,
            tax_minor=0,
            total_minor=rep.total_bookings * 100,
            status="summary",
        )
