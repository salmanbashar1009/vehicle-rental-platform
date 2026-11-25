"""Vehicle media uploads and availability calendar service."""

from datetime import datetime
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NotFoundError, ValidationDomainError
from app.integrations.s3_storage import S3StorageClient, validate_upload_bytes
from app.modules.vehicles.models import VehicleImage
from app.modules.vehicles.repository import VehicleRepository
from app.modules.vehicles.schemas import ScheduleBlockResponse, VehicleImageResponse

ALLOWED_IMAGE_MIMES = frozenset({"image/jpeg", "image/png", "image/webp"})


class VehicleMediaService:
    """Handles vehicle image uploads and calendar schedule block reads."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._repo = VehicleRepository(session)

    async def upload_image(
        self,
        vehicle_id: UUID,
        *,
        data: bytes,
        filename: str,
        is_primary: bool,
        storage: S3StorageClient,
    ) -> VehicleImageResponse:
        """Validate image bytes and store reference in S3 and DB."""
        vehicle = await self._repo.get_by_id(vehicle_id)
        if vehicle is None:
            raise NotFoundError("Vehicle not found.")
        mime, ext = validate_upload_bytes(
            data, filename=filename, allowed_mimes=ALLOWED_IMAGE_MIMES
        )
        key = storage.upload_bytes(prefix=f"vehicles/{vehicle_id}", data=data, mime=mime, ext=ext)
        img = VehicleImage(
            vehicle_id=vehicle_id,
            object_key=key,
            is_primary=is_primary,
            sort_order=len(vehicle.images),
        )
        self._session.add(img)
        await self._session.commit()
        await self._session.refresh(img)
        return VehicleImageResponse.model_validate(img)

    async def get_calendar(
        self, vehicle_id: UUID, *, start_at: datetime, end_at: datetime
    ) -> list[ScheduleBlockResponse]:
        """Return schedule blocks for vehicle availability calendar."""
        if end_at <= start_at:
            raise ValidationDomainError("end_at must be after start_at.")
        if await self._repo.get_by_id(vehicle_id) is None:
            raise NotFoundError("Vehicle not found.")
        blocks = await self._repo.get_calendar_blocks(vehicle_id, start_at=start_at, end_at=end_at)
        return [
            ScheduleBlockResponse(
                id=b.id,
                block_type=b.block_type,
                source_id=b.source_id,
                start_at=b.time_range.lower,
                end_at=b.time_range.upper,
            )
            for b in blocks
        ]
