"""Public and admin service catalogue router."""

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NotFoundError
from app.database.session import get_db_session
from app.modules.services.models import ServiceCategory
from app.modules.services.schemas import ServiceCategoryResponse

router = APIRouter(prefix="/public/catalog/services", tags=["Public Catalogue"])


@router.get("", response_model=list[ServiceCategoryResponse])
async def list_public_services(
    session: AsyncSession = Depends(get_db_session),
) -> list[ServiceCategoryResponse]:
    """Return active service categories ordered for public display."""
    stmt = (
        select(ServiceCategory)
        .where(ServiceCategory.is_active.is_(True))
        .order_by(ServiceCategory.display_order.asc())
    )
    rows = (await session.execute(stmt)).scalars().all()
    return [ServiceCategoryResponse.model_validate(row) for row in rows]


@router.get("/{slug}", response_model=ServiceCategoryResponse)
async def get_public_service(
    slug: str,
    session: AsyncSession = Depends(get_db_session),
) -> ServiceCategoryResponse:
    """Return single service category detail by slug."""
    stmt = select(ServiceCategory).where(
        ServiceCategory.slug == slug, ServiceCategory.is_active.is_(True)
    )
    row = (await session.execute(stmt)).scalar_one_or_none()
    if row is None:
        raise NotFoundError("Service category not found.")
    return ServiceCategoryResponse.model_validate(row)
