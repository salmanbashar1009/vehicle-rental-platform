"""Booking creation and query service."""

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, NotFoundError, ValidationDomainError
from app.core.idempotency import (
    compute_request_hash,
    get_idempotent_replay,
    save_idempotent_response,
)
from app.core.pagination import PaginatedResponse, PaginationParams
from app.core.security import generate_opaque_token, hash_token
from app.modules.audit.service import AuditService
from app.modules.authentication.dependencies import CurrentActor
from app.modules.bookings.helpers import (
    assert_customer_owns_booking,
    generate_booking_ref,
    serialize_booking,
)
from app.modules.bookings.models import Booking, BookingStatusHistory, BookingStop
from app.modules.bookings.repository import BookingRepository
from app.modules.bookings.schemas import BookingCreateRequest, BookingResponse
from app.modules.customers.service import CustomerService
from app.modules.services.models import ServiceCategory
from app.modules.vehicles.repository import VehicleRepository


class BookingService:
    """Handles booking requests, listings, and ownership-checked retrieval."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._repo = BookingRepository(session)

    async def create_booking(
        self,
        payload: BookingCreateRequest,
        *,
        actor: CurrentActor | None,
        idempotency_key: str,
        correlation_id: str | None,
    ) -> BookingResponse:
        """Idempotently create a booking request with ordered stops."""
        actor_scope = f"booking:user:{actor.user_id}" if actor else "booking:guest"
        req_hash = compute_request_hash(payload.model_dump(mode="json"))
        replay = await get_idempotent_replay(
            self._session,
            actor_scope=actor_scope,
            idempotency_key=idempotency_key,
            request_hash=req_hash,
        )
        if replay is not None:
            return BookingResponse.model_validate(replay)

        svc = (
            await self._session.execute(
                select(ServiceCategory).where(
                    ServiceCategory.slug == payload.service_slug,
                    ServiceCategory.is_active.is_(True),
                )
            )
        ).scalar_one_or_none()
        if svc is None:
            raise ValidationDomainError("Selected service category is invalid or inactive.")

        if payload.preferred_vehicle_id is not None:
            veh_repo = VehicleRepository(self._session)
            vehicle = await veh_repo.get_by_id(payload.preferred_vehicle_id)
            if vehicle is None:
                raise NotFoundError("Preferred vehicle not found.")
            busy = await veh_repo.overlapping_vehicle_ids(
                start_at=payload.pickup_at, end_at=payload.expected_end_at
            )
            if vehicle.id in busy or vehicle.status in ("maintenance", "out_of_service"):
                raise ConflictError("Preferred vehicle is unavailable for the selected schedule.")

        cust_service = CustomerService(self._session)
        raw_claim: str | None = None
        if actor is not None:
            customer = await cust_service.get_or_create_for_user(actor)
        else:
            if not payload.customer_name:
                raise ValidationDomainError("customer_name is required for guest bookings.")
            customer = await cust_service.get_or_create_guest(
                full_name=payload.customer_name,
                email=payload.customer_email,
                phone=payload.customer_phone,
            )
            raw_claim = generate_opaque_token()

        booking = Booking(
            reference=generate_booking_ref(),
            customer_id=customer.id,
            service_category_id=svc.id,
            preferred_vehicle_id=payload.preferred_vehicle_id,
            status="requested",
            pickup_at=payload.pickup_at,
            expected_end_at=payload.expected_end_at,
            passenger_count=payload.passenger_count,
            luggage_count=payload.luggage_count,
            cargo_details_json=payload.cargo_details_json,
            service_metadata_json=payload.service_metadata_json,
            special_instructions=payload.special_instructions,
            claim_token_hash=hash_token(raw_claim) if raw_claim else None,
        )
        self._session.add(booking)
        await self._session.flush()
        for idx, stop in enumerate(payload.stops, start=1):
            self._session.add(
                BookingStop(
                    booking_id=booking.id,
                    seq_order=idx,
                    stop_type=stop.stop_type,
                    address=stop.address.strip(),
                    lat=stop.lat,
                    lng=stop.lng,
                )
            )
        self._session.add(
            BookingStatusHistory(
                booking_id=booking.id,
                from_status=None,
                to_status="requested",
                changed_by=actor.user_id if actor else None,
                reason="Booking request submitted",
            )
        )
        await self._session.flush()
        await self._session.refresh(booking)

        dto = serialize_booking(booking, include_internal=False, claim_token=raw_claim)
        await save_idempotent_response(
            self._session,
            actor_scope=actor_scope,
            idempotency_key=idempotency_key,
            request_hash=req_hash,
            status_code=201,
            response_body=dto.model_dump(mode="json"),
        )
        AuditService.record(
            self._session,
            actor_id=actor.user_id if actor else None,
            actor_role=actor.primary_role if actor else "guest",
            action="booking.created",
            resource_type="booking",
            resource_id=str(booking.id),
            after_state={"reference": booking.reference, "status": booking.status},
            correlation_id=correlation_id,
        )
        await self._session.commit()
        return dto

    async def list_bookings(
        self,
        *,
        actor: CurrentActor,
        pagination: PaginationParams,
        status: str | None = None,
        search: str | None = None,
    ) -> PaginatedResponse[BookingResponse]:
        """List bookings scoped by staff RBAC or owning customer."""
        is_staff = actor.has_permission("bookings.read")
        customer_id: UUID | None = None
        if not is_staff:
            profile = await CustomerService(self._session).get_or_create_for_user(actor)
            customer_id = profile.id
        rows, total = await self._repo.list_bookings(
            pagination=pagination, customer_id=customer_id, status=status, search=search
        )
        items = [serialize_booking(b, include_internal=is_staff) for b in rows]
        return PaginatedResponse.create(
            items=items, page=pagination.page, page_size=pagination.page_size, total_items=total
        )

    async def get_booking(self, booking_id: UUID, *, actor: CurrentActor) -> BookingResponse:
        """Fetch single booking enforcing staff permission or customer ownership."""
        booking = await self._repo.get_by_id(booking_id)
        if booking is None:
            raise NotFoundError("Booking not found.")
        is_staff = actor.has_permission("bookings.read")
        if not is_staff:
            await assert_customer_owns_booking(self._session, booking, actor)
        return serialize_booking(booking, include_internal=is_staff)
