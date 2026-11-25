"""Document and driver licence expiry reminder scanner."""

from datetime import UTC, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.drivers.models import DriverProfile
from app.modules.maintenance.schemas import ExpiryScanResponse
from app.modules.notifications.service import NotificationService
from app.modules.users.models import Role, UserRole
from app.modules.vehicles.models import VehicleDocument


class ExpiryReminderService:
    """Scans vehicle compliance documents and driver licences expiring within 30 days."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def scan_expiry_reminders(self) -> ExpiryScanResponse:
        """Emit deduplicated notifications for expiring vehicle docs and driver licences."""
        horizon = datetime.now(UTC).date() + timedelta(days=30)
        mgr_ids = list(
            (
                await self._session.execute(
                    select(UserRole.user_id)
                    .join(Role, UserRole.role_id == Role.id)
                    .where(Role.slug.in_(("owner", "fleet_manager")))
                )
            )
            .scalars()
            .all()
        )
        target_uid = mgr_ids[0] if mgr_ids else None
        doc_alerts = 0
        lic_alerts = 0

        if target_uid is not None:
            docs = (
                (
                    await self._session.execute(
                        select(VehicleDocument).where(VehicleDocument.expires_at <= horizon)
                    )
                )
                .scalars()
                .all()
            )
            for doc in docs:
                await NotificationService.enqueue(
                    self._session,
                    user_id=target_uid,
                    event_type="fleet.doc_expiring",
                    title=f"Vehicle {doc.doc_type} expiring {doc.expires_at}",
                    body=f"Document {doc.doc_number} requires renewal.",
                    dedup_key=f"doc_exp:{doc.id}:{doc.expires_at}",
                    priority="high",
                    resource_type="vehicle",
                    resource_id=str(doc.vehicle_id),
                )
                doc_alerts += 1

        drivers = (
            (
                await self._session.execute(
                    select(DriverProfile).where(
                        DriverProfile.deleted_at.is_(None),
                        DriverProfile.licence_expiry <= horizon,
                    )
                )
            )
            .scalars()
            .all()
        )
        for drv in drivers:
            await NotificationService.enqueue(
                self._session,
                user_id=drv.user_id,
                event_type="driver.licence_expiring",
                title=f"Driving licence expiring {drv.licence_expiry}",
                body="Please upload renewed driving licence before expiry.",
                dedup_key=f"lic_exp:{drv.id}:{drv.licence_expiry}",
                priority="high",
                resource_type="driver",
                resource_id=str(drv.id),
            )
            lic_alerts += 1

        await self._session.commit()
        return ExpiryScanResponse(doc_alerts_created=doc_alerts, licence_alerts_created=lic_alerts)
