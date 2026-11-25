"""Customer profile service for authenticated customers and guest enquiries."""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ValidationDomainError
from app.modules.authentication.dependencies import CurrentActor
from app.modules.customers.models import CustomerProfile
from app.modules.customers.schemas import (
    CustomerProfileResponse,
    CustomerProfileUpdateRequest,
)


class CustomerService:
    """Manages customer profiles and guest-to-user linking."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_or_create_for_user(self, actor: CurrentActor) -> CustomerProfile:
        """Return existing CustomerProfile for user_id or create one."""
        stmt = select(CustomerProfile).where(
            CustomerProfile.user_id == actor.user_id,
            CustomerProfile.deleted_at.is_(None),
        )
        profile = (await self._session.execute(stmt)).scalar_one_or_none()
        if profile is not None:
            return profile

        profile = CustomerProfile(
            user_id=actor.user_id,
            full_name=actor.full_name,
            email=actor.email,
            phone=actor.phone,
        )
        self._session.add(profile)
        await self._session.flush()
        return profile

    async def get_or_create_guest(
        self, *, full_name: str, email: str | None, phone: str | None
    ) -> CustomerProfile:
        """Create a guest customer profile for an unauthenticated enquiry."""
        if not email and not phone:
            raise ValidationDomainError("Customer email or phone is required.")
        profile = CustomerProfile(
            user_id=None,
            full_name=full_name.strip(),
            email=email.lower() if email else None,
            phone=phone.strip() if phone else None,
        )
        self._session.add(profile)
        await self._session.flush()
        return profile

    async def get_my_profile(self, actor: CurrentActor) -> CustomerProfileResponse:
        """Fetch or provision customer's own profile."""
        profile = await self.get_or_create_for_user(actor)
        await self._session.commit()
        return CustomerProfileResponse.model_validate(profile)

    async def update_my_profile(
        self, actor: CurrentActor, payload: CustomerProfileUpdateRequest
    ) -> CustomerProfileResponse:
        """Update customer's own profile contact fields."""
        profile = await self.get_or_create_for_user(actor)
        if payload.full_name is not None:
            profile.full_name = payload.full_name.strip()
        if payload.email is not None:
            profile.email = payload.email.lower()
        if payload.phone is not None:
            profile.phone = payload.phone.strip()
        await self._session.commit()
        await self._session.refresh(profile)
        return CustomerProfileResponse.model_validate(profile)
