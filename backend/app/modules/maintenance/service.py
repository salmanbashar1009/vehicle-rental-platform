"""Maintenance schedule locking service."""

from uuid import UUID

from asyncpg.types import Range
from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, NotFoundError
from app.modules.audit.service import AuditService
from app.modules.authentication.dependencies import CurrentActor
from app.modules.maintenance.models import MaintenanceRecord
from app.modules.maintenance.schemas import (
    MaintenanceCreateRequest,
    MaintenanceResponse,
    MaintenanceStatusUpdateRequest,
)
from app.modules.vehicles.models import Vehicle, VehicleScheduleBlock


class MaintenanceService:
    """Locks vehicle calendars on maintenance and releases on completion/cancellation."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def schedule_maintenance(
        self, payload: MaintenanceCreateRequest, *, actor: CurrentActor, correlation_id: str | None
    ) -> MaintenanceResponse:
        """Create maintenance record + active VehicleScheduleBlock (`409` on overlap)."""
        vehicle = (
            await self._session.execute(
                select(Vehicle).where(
                    Vehicle.id == payload.vehicle_id, Vehicle.deleted_at.is_(None)
                )
            )
        ).scalar_one_or_none()
        if vehicle is None:
            raise NotFoundError("Vehicle not found.")

        record = MaintenanceRecord(
            vehicle_id=vehicle.id,
            maint_type=payload.maint_type,
            description=payload.description,
            provider_name=payload.provider_name,
            scheduled_start=payload.scheduled_start,
            scheduled_end=payload.scheduled_end,
            cost_minor=payload.cost_minor,
            currency=payload.currency.upper(),
            odometer_km=payload.odometer_km,
            receipt_key=payload.receipt_key,
            status="scheduled",
            created_by=actor.user_id,
        )
        self._session.add(record)
        await self._session.flush()

        block = VehicleScheduleBlock(
            vehicle_id=vehicle.id,
            block_type="maintenance",
            source_id=record.id,
            time_range=Range(
                payload.scheduled_start, payload.scheduled_end, lower_inc=True, upper_inc=False
            ),
            is_active=True,
        )
        self._session.add(block)
        try:
            await self._session.flush()
        except IntegrityError as exc:
            await self._session.rollback()
            raise ConflictError(
                "Vehicle has a conflicting reservation or maintenance block in this window."
            ) from exc

        AuditService.record(
            self._session,
            actor_id=actor.user_id,
            actor_role=actor.primary_role,
            action="maintenance.scheduled",
            resource_type="maintenance",
            resource_id=str(record.id),
            after_state={"vehicle_id": str(vehicle.id), "maint_type": payload.maint_type},
            correlation_id=correlation_id,
        )
        await self._session.commit()
        await self._session.refresh(record)
        return MaintenanceResponse.model_validate(record)

    async def list_maintenance(self, vehicle_id: UUID | None = None) -> list[MaintenanceResponse]:
        """List fleet maintenance records optionally filtered by vehicle."""
        stmt = select(MaintenanceRecord).order_by(MaintenanceRecord.scheduled_start.desc())
        if vehicle_id is not None:
            stmt = stmt.where(MaintenanceRecord.vehicle_id == vehicle_id)
        rows = (await self._session.execute(stmt)).scalars().all()
        return [MaintenanceResponse.model_validate(r) for r in rows]

    async def update_status(
        self,
        maint_id: UUID,
        payload: MaintenanceStatusUpdateRequest,
        *,
        actor: CurrentActor,
        correlation_id: str | None,
    ) -> MaintenanceResponse:
        """Advance maintenance status and release VehicleScheduleBlock when completed/cancelled."""
        rec = (
            await self._session.execute(
                select(MaintenanceRecord).where(MaintenanceRecord.id == maint_id).with_for_update()
            )
        ).scalar_one_or_none()
        if rec is None:
            raise NotFoundError("Maintenance record not found.")

        prev = rec.status
        rec.status = payload.status
        if payload.cost_minor is not None:
            rec.cost_minor = payload.cost_minor
        if payload.odometer_km is not None:
            rec.odometer_km = payload.odometer_km
        if payload.receipt_key is not None:
            rec.receipt_key = payload.receipt_key

        if payload.status in ("completed", "cancelled"):
            await self._session.execute(
                update(VehicleScheduleBlock)
                .where(
                    VehicleScheduleBlock.source_id == rec.id,
                    VehicleScheduleBlock.is_active.is_(True),
                )
                .values(is_active=False)
            )
            if payload.odometer_km is not None:
                veh = (
                    await self._session.execute(select(Vehicle).where(Vehicle.id == rec.vehicle_id))
                ).scalar_one()
                if payload.odometer_km > veh.odometer_km:
                    veh.odometer_km = payload.odometer_km
                if veh.status == "maintenance":
                    veh.status = "available"

        AuditService.record(
            self._session,
            actor_id=actor.user_id,
            actor_role=actor.primary_role,
            action="maintenance.status_updated",
            resource_type="maintenance",
            resource_id=str(rec.id),
            before_state={"status": prev},
            after_state={"status": rec.status},
            correlation_id=correlation_id,
        )
        await self._session.commit()
        await self._session.refresh(rec)
        return MaintenanceResponse.model_validate(rec)
