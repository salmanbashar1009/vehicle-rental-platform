"""Driver management business operations."""

from datetime import datetime
from uuid import UUID

from asyncpg.types import Range
from sqlalchemy import ColumnElement, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, NotFoundError, ValidationDomainError
from app.core.pagination import PaginatedResponse, PaginationParams
from app.core.security import hash_password
from app.modules.audit.service import AuditService
from app.modules.drivers.models import DriverProfile, DriverScheduleBlock
from app.modules.drivers.schemas import (
    DRIVER_AVAILABILITY_STATUSES,
    DriverCreateRequest,
    DriverResponse,
    DriverUpdateRequest,
)
from app.modules.users.models import User
from app.modules.users.repository import UserRepository


def _to_driver_response(driver: DriverProfile) -> DriverResponse:
    return DriverResponse(
        id=driver.id,
        user_id=driver.user_id,
        full_name=driver.user.full_name,
        email=driver.user.email,
        phone=driver.user.phone,
        licence_number=driver.licence_number,
        licence_classes_json=driver.licence_classes_json,
        licence_expiry=driver.licence_expiry,
        emergency_contact_name=driver.emergency_contact_name,
        emergency_contact_phone=driver.emergency_contact_phone,
        employment_status=driver.employment_status,
        availability_status=driver.availability_status,
        created_at=driver.created_at,
    )


class DriverService:
    """Driver CRUD, licence validation, and schedule availability checks."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._users = UserRepository(session)

    async def list_drivers(
        self, pagination: PaginationParams, *, availability_status: str | None = None
    ) -> PaginatedResponse[DriverResponse]:
        """List non-deleted drivers with pagination."""
        filters: list[ColumnElement[bool]] = [DriverProfile.deleted_at.is_(None)]
        if availability_status:
            filters.append(DriverProfile.availability_status == availability_status)

        total = int(
            (
                await self._session.execute(select(func.count(DriverProfile.id)).where(*filters))
            ).scalar_one()
        )
        rows = (
            (
                await self._session.execute(
                    select(DriverProfile)
                    .where(*filters)
                    .order_by(DriverProfile.created_at.desc())
                    .offset(pagination.offset)
                    .limit(pagination.page_size)
                )
            )
            .scalars()
            .all()
        )
        return PaginatedResponse.create(
            items=[_to_driver_response(r) for r in rows],
            page=pagination.page,
            page_size=pagination.page_size,
            total_items=total,
        )

    async def create_driver(
        self,
        payload: DriverCreateRequest,
        *,
        actor_id: UUID,
        actor_role: str,
        correlation_id: str | None,
    ) -> DriverResponse:
        """Create a driver user + profile atomically."""
        email = payload.email.lower() if payload.email else None
        phone = payload.phone.strip()
        if await self._users.exists_email_or_phone(email, phone):
            raise ConflictError("A user with this email or phone already exists.")

        licence_norm = payload.licence_number.strip().upper()
        existing_lic = (
            await self._session.execute(
                select(DriverProfile).where(
                    func.upper(DriverProfile.licence_number) == licence_norm
                )
            )
        ).scalar_one_or_none()
        if existing_lic is not None:
            raise ConflictError("A driver with this licence number already exists.")

        roles = await self._users.get_roles_by_slugs(["driver"])
        user = User(
            email=email,
            phone=phone,
            full_name=payload.full_name.strip(),
            password_hash=hash_password(payload.password),
            roles=roles,
        )
        self._session.add(user)
        await self._session.flush()

        driver = DriverProfile(
            user_id=user.id,
            licence_number=licence_norm,
            licence_classes_json=payload.licence_classes_json,
            licence_expiry=payload.licence_expiry,
            emergency_contact_name=payload.emergency_contact_name,
            emergency_contact_phone=payload.emergency_contact_phone,
        )
        self._session.add(driver)
        await self._session.flush()
        AuditService.record(
            self._session,
            actor_id=actor_id,
            actor_role=actor_role,
            action="driver.created",
            resource_type="driver",
            resource_id=str(driver.id),
            after_state={"licence_number": licence_norm},
            correlation_id=correlation_id,
        )
        await self._session.commit()
        await self._session.refresh(driver)
        return _to_driver_response(driver)

    async def update_driver(
        self,
        driver_id: UUID,
        payload: DriverUpdateRequest,
        *,
        actor_id: UUID,
        actor_role: str,
        correlation_id: str | None,
    ) -> DriverResponse:
        """Update driver profile or availability status."""
        stmt = select(DriverProfile).where(
            DriverProfile.id == driver_id, DriverProfile.deleted_at.is_(None)
        )
        driver = (await self._session.execute(stmt)).scalar_one_or_none()
        if driver is None:
            raise NotFoundError("Driver not found.")
        if (
            payload.availability_status is not None
            and payload.availability_status not in DRIVER_AVAILABILITY_STATUSES
        ):
            raise ValidationDomainError("Invalid driver availability status.")

        before = {"availability_status": driver.availability_status}
        for field, value in payload.model_dump(exclude_none=True).items():
            setattr(driver, field, value)

        AuditService.record(
            self._session,
            actor_id=actor_id,
            actor_role=actor_role,
            action="driver.updated",
            resource_type="driver",
            resource_id=str(driver.id),
            before_state=before,
            after_state={"availability_status": driver.availability_status},
            correlation_id=correlation_id,
        )
        await self._session.commit()
        await self._session.refresh(driver)
        return _to_driver_response(driver)

    async def overlapping_driver_ids(
        self, *, start_at: datetime, end_at: datetime, exclude_source_id: UUID | None = None
    ) -> set[UUID]:
        """Return driver IDs with schedule blocks intersecting [start_at, end_at)."""
        window = Range(start_at, end_at, lower_inc=True, upper_inc=False)
        stmt = select(DriverScheduleBlock.driver_id).where(
            DriverScheduleBlock.is_active.is_(True),
            DriverScheduleBlock.time_range.op("&&")(window),
        )
        if exclude_source_id is not None:
            stmt = stmt.where(DriverScheduleBlock.source_id != exclude_source_id)
        return set((await self._session.execute(stmt)).scalars().all())
