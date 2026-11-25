"""Vehicle fleet CRUD business operations."""

from datetime import datetime
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, NotFoundError, ValidationDomainError
from app.core.pagination import PaginatedResponse, PaginationParams
from app.modules.audit.service import AuditService
from app.modules.vehicles.models import Vehicle
from app.modules.vehicles.repository import VehicleRepository
from app.modules.vehicles.schemas import (
    VEHICLE_STATUSES,
    VehicleCreateRequest,
    VehicleResponse,
    VehicleUpdateRequest,
)


class VehicleService:
    """Fleet listing and CRUD operations."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._repo = VehicleRepository(session)

    async def list_vehicles(
        self,
        *,
        pagination: PaginationParams,
        category: str | None = None,
        min_seats: int | None = None,
        max_rate_minor: int | None = None,
        facility: str | None = None,
        start_at: datetime | None = None,
        end_at: datetime | None = None,
        public_only: bool = False,
    ) -> PaginatedResponse[VehicleResponse]:
        """List vehicles with optional availability indicator for a time window."""
        vehicles, total = await self._repo.list_vehicles(
            pagination=pagination,
            category=category,
            min_seats=min_seats,
            max_rate_minor=max_rate_minor,
            facility=facility,
            public_only=public_only,
        )
        busy_ids: set[UUID] = set()
        check_window = start_at is not None and end_at is not None
        if start_at is not None and end_at is not None:
            if end_at <= start_at:
                raise ValidationDomainError("end_at must be after start_at.")
            busy_ids = await self._repo.overlapping_vehicle_ids(start_at=start_at, end_at=end_at)

        items: list[VehicleResponse] = []
        for v in vehicles:
            dto = VehicleResponse.model_validate(v)
            if check_window:
                dto.is_available_for_window = v.id not in busy_ids and v.status not in (
                    "maintenance",
                    "out_of_service",
                )
            items.append(dto)
        return PaginatedResponse.create(
            items=items, page=pagination.page, page_size=pagination.page_size, total_items=total
        )

    async def get_vehicle(self, vehicle_id: UUID, *, public_only: bool = False) -> VehicleResponse:
        """Fetch vehicle details."""
        vehicle = await self._repo.get_by_id(vehicle_id)
        if vehicle is None or (public_only and not vehicle.is_public):
            raise NotFoundError("Vehicle not found.")
        return VehicleResponse.model_validate(vehicle)

    async def create_vehicle(
        self,
        payload: VehicleCreateRequest,
        *,
        actor_id: UUID,
        actor_role: str,
        correlation_id: str | None,
    ) -> VehicleResponse:
        """Register a new fleet vehicle."""
        plate = payload.plate_number.strip().upper()
        if await self._repo.get_by_plate(plate) is not None:
            raise ConflictError("A vehicle with this plate number already exists.")

        vehicle = Vehicle(
            plate_number=plate,
            name=payload.name.strip(),
            category=payload.category.strip().lower(),
            make=payload.make.strip(),
            model=payload.model.strip(),
            year=payload.year,
            seat_capacity=payload.seat_capacity,
            luggage_capacity=payload.luggage_capacity,
            cargo_volume_m3=payload.cargo_volume_m3,
            fuel_type=payload.fuel_type.strip().lower(),
            facilities_json=payload.facilities_json,
            indicative_daily_rate_minor=payload.indicative_daily_rate_minor,
            currency=payload.currency.upper(),
            odometer_km=payload.odometer_km,
            is_public=payload.is_public,
            description=payload.description,
        )
        self._session.add(vehicle)
        await self._session.flush()
        AuditService.record(
            self._session,
            actor_id=actor_id,
            actor_role=actor_role,
            action="vehicle.created",
            resource_type="vehicle",
            resource_id=str(vehicle.id),
            after_state={"plate_number": plate, "status": vehicle.status},
            correlation_id=correlation_id,
        )
        await self._session.commit()
        await self._session.refresh(vehicle)
        return VehicleResponse.model_validate(vehicle)

    async def update_vehicle(
        self,
        vehicle_id: UUID,
        payload: VehicleUpdateRequest,
        *,
        actor_id: UUID,
        actor_role: str,
        correlation_id: str | None,
    ) -> VehicleResponse:
        """Update vehicle specs or operational status with audit trail."""
        vehicle = await self._repo.get_by_id(vehicle_id)
        if vehicle is None:
            raise NotFoundError("Vehicle not found.")
        if payload.status is not None and payload.status not in VEHICLE_STATUSES:
            raise ValidationDomainError("Invalid vehicle status.")

        before = {"status": vehicle.status, "odometer_km": vehicle.odometer_km}
        for field, value in payload.model_dump(exclude_none=True).items():
            setattr(vehicle, field, value)

        AuditService.record(
            self._session,
            actor_id=actor_id,
            actor_role=actor_role,
            action="vehicle.updated",
            resource_type="vehicle",
            resource_id=str(vehicle.id),
            before_state=before,
            after_state={"status": vehicle.status, "odometer_km": vehicle.odometer_km},
            correlation_id=correlation_id,
        )
        await self._session.commit()
        await self._session.refresh(vehicle)
        return VehicleResponse.model_validate(vehicle)
