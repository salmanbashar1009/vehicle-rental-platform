"""Customer self-registration service."""

from uuid import uuid4

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, ValidationDomainError
from app.core.security import hash_password
from app.modules.audit.service import AuditService
from app.modules.authentication.schemas import RegisterRequest, TokenPairResponse
from app.modules.authentication.token_issuer import issue_session_tokens
from app.modules.users.models import User
from app.modules.users.repository import UserRepository


class RegistrationService:
    """Handles customer self-registration and initial session issuance."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._users = UserRepository(session)

    async def register_customer(
        self,
        payload: RegisterRequest,
        *,
        ip_address: str | None,
        user_agent: str | None,
        correlation_id: str | None,
    ) -> TokenPairResponse:
        """Register a customer account and issue initial access/refresh tokens."""
        if not payload.email and not payload.phone:
            raise ValidationDomainError("Either email or phone is required.")
        email = payload.email.lower() if payload.email else None
        phone = payload.phone.strip() if payload.phone else None
        if await self._users.exists_email_or_phone(email, phone):
            raise ConflictError("An account with this email or phone already exists.")

        roles = await self._users.get_roles_by_slugs(["customer"])
        user = User(
            email=email,
            phone=phone,
            full_name=payload.full_name.strip(),
            password_hash=hash_password(payload.password),
            roles=roles,
        )
        self._session.add(user)
        await self._session.flush()
        AuditService.record(
            self._session,
            actor_id=user.id,
            actor_role="customer",
            action="auth.registered",
            resource_type="user",
            resource_id=str(user.id),
            correlation_id=correlation_id,
            ip_address=ip_address,
        )
        pair = await issue_session_tokens(
            self._session,
            user,
            family_id=uuid4(),
            ip_address=ip_address,
            user_agent=user_agent,
        )
        await self._session.commit()
        return pair
