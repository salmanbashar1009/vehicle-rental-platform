"""Seed definitions for the 8 supported transport service categories."""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.services.models import ServiceCategory, ServiceWorkflow

STANDARD_STEPS = [
    "assigned",
    "en_route_to_pickup",
    "arrived_at_pickup",
    "picked_up",
    "journey_started",
    "at_destination",
    "service_completed",
]

CARGO_STEPS = [
    "assigned",
    "en_route_to_pickup",
    "arrived_at_pickup",
    "loading_started",
    "loading_completed",
    "picked_up",
    "journey_started",
    "at_destination",
    "unloading_started",
    "unloading_completed",
    "service_completed",
]

DEFAULT_SERVICES: list[tuple[str, str, str, bool, list[str], dict[str, object]]] = [
    (
        "tour_travel",
        "Tour & Travel",
        "Multi-destination guided chauffeur journeys with flexible stops and overnight stays.",
        True,
        STANDARD_STEPS,
        {"fields": ["destinations_summary", "overnight_stay", "itinerary_notes"]},
    ),
    (
        "event_transport",
        "Event Transportation",
        "Coordinated group and VIP arrivals for weddings, conferences, and private events.",
        True,
        STANDARD_STEPS,
        {"fields": ["event_venue", "return_trip_required", "passenger_count"]},
    ),
    (
        "house_shifting_cargo",
        "House Shifting & Cargo",
        "Dedicated vans and trucks with optional loading and unloading crew support.",
        True,
        CARGO_STEPS,
        {"fields": ["cargo_volume", "pickup_floor", "dropoff_floor", "has_elevator", "needs_crew"]},
    ),
    (
        "airport_transfer",
        "Airport Transfer",
        "Punctual terminal pickup and drop-off with flight tracking and luggage handling.",
        False,
        STANDARD_STEPS,
        {"fields": ["flight_number", "terminal", "transfer_direction", "luggage_count"]},
    ),
    (
        "corporate_transport",
        "Corporate Transportation",
        "Executive travel, recurring office commutes, and consolidated corporate billing.",
        True,
        STANDARD_STEPS,
        {"fields": ["company_name", "cost_center", "recurring_schedule"]},
    ),
    (
        "periodic_rental",
        "Daily, Weekly & Monthly Rental",
        "Chauffeur-driven short and long-term vehicle allocations with clear mileage terms.",
        True,
        STANDARD_STEPS,
        {"fields": ["rental_period_type", "estimated_daily_km"]},
    ),
    (
        "personal_transport",
        "Personal Transportation",
        "Comfortable point-to-point or hourly private rides tailored to your schedule.",
        False,
        STANDARD_STEPS,
        {"fields": ["passenger_count", "special_requests"]},
    ),
    (
        "custom_service",
        "Customized Service",
        "Bespoke multi-vehicle or specialized transportation tailored to unique requirements.",
        True,
        STANDARD_STEPS,
        {"fields": ["custom_requirements"]},
    ),
]


async def seed_service_categories(session: AsyncSession) -> None:
    """Idempotently seed all 8 transport service categories and workflows."""
    existing = {c.slug: c for c in (await session.execute(select(ServiceCategory))).scalars().all()}
    for idx, (slug, name, desc, req_quote, steps, form_schema) in enumerate(DEFAULT_SERVICES):
        if slug in existing:
            continue
        cat = ServiceCategory(
            slug=slug,
            name=name,
            description=desc,
            requires_quote=req_quote,
            is_active=True,
            display_order=idx + 1,
        )
        session.add(cat)
        await session.flush()
        session.add(
            ServiceWorkflow(
                service_category_id=cat.id,
                steps_json=steps,
                form_schema_json=form_schema,
            )
        )
    await session.flush()
