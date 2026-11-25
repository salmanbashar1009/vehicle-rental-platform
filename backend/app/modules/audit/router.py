"""FastAPI router for immutable audit logs."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.pagination import PaginatedResponse, PaginationParams
from app.database.session import get_db_session
from app.modules.audit.schemas import AuditLogResponse
from app.modules.audit.service import AuditService
from app.modules.authentication.dependencies import CurrentActor, require_permissions

router = APIRouter(prefix="/audit", tags=["Audit"])


@router.get("/logs", response_model=PaginatedResponse[AuditLogResponse])
async def list_audit_logs(
    pagination: PaginationParams = Depends(),
    resource_type: str | None = None,
    action: str | None = None,
    _actor: CurrentActor = Depends(require_permissions("audit.read")),
    session: AsyncSession = Depends(get_db_session),
) -> PaginatedResponse[AuditLogResponse]:
    """List immutable audit trail records (owner only)."""
    return await AuditService.list_logs(
        session,
        pagination=pagination,
        resource_type=resource_type,
        action=action,
    )
