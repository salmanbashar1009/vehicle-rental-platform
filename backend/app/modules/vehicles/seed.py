"""Idempotent sample fleet seeder for local development and showcase."""

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.vehicles.models import Vehicle

SAMPLE_VEHICLES: list[dict[str, object]] = [
    {
        "plate_number": "VF-EXEC-101",
        "name": "Mercedes-Benz E-Class Executive",
        "category": "sedan",
        "make": "Mercedes-Benz",
        "model": "E 350",
        "year": 2025,
        "seat_capacity": 4,
        "luggage_capacity": 3,
        "fuel_type": "hybrid",
        "facilities_json": ["AC", "WiFi", "USB-C", "Bottled Water", "Leather Interior"],
        "indicative_daily_rate_minor": 18000,
        "currency": "USD",
        "status": "available",
        "odometer_km": 12400,
        "is_public": True,
        "description": (
            "Chauffeur-driven executive sedan suited for airport transfers and corporate travel."
        ),
    },
    {
        "plate_number": "VF-SUV-202",
        "name": "Cadillac Escalade VIP SUV",
        "category": "suv",
        "make": "Cadillac",
        "model": "Escalade",
        "year": 2025,
        "seat_capacity": 6,
        "luggage_capacity": 5,
        "fuel_type": "petrol",
        "facilities_json": ["AC", "WiFi", "Leather Seats", "Privacy Glass", "USB-C"],
        "indicative_daily_rate_minor": 26000,
        "currency": "USD",
        "status": "available",
        "odometer_km": 9800,
        "is_public": True,
        "description": "Full-size luxury SUV for VIP arrivals, events, and family touring.",
    },
    {
        "plate_number": "VF-VAN-303",
        "name": "Mercedes Sprinter Tourer",
        "category": "van",
        "make": "Mercedes-Benz",
        "model": "Sprinter 319",
        "year": 2024,
        "seat_capacity": 12,
        "luggage_capacity": 12,
        "fuel_type": "diesel",
        "facilities_json": ["Dual AC", "WiFi", "Reclining Seats", "PA System"],
        "indicative_daily_rate_minor": 22000,
        "currency": "USD",
        "status": "available",
        "odometer_km": 24100,
        "is_public": True,
        "description": (
            "Spacious high-roof touring van for multi-day group itineraries and delegations."
        ),
    },
    {
        "plate_number": "VF-CRG-404",
        "name": "Isuzu NPR Covered Box Truck",
        "category": "cargo",
        "make": "Isuzu",
        "model": "NPR-HD",
        "year": 2024,
        "seat_capacity": 3,
        "luggage_capacity": 20,
        "cargo_volume_m3": 18.5,
        "fuel_type": "diesel",
        "facilities_json": ["Hydraulic Liftgate", "Tie-Down Straps", "GPS Monitored"],
        "indicative_daily_rate_minor": 19500,
        "currency": "USD",
        "status": "available",
        "odometer_km": 31500,
        "is_public": True,
        "description": (
            "Enclosed box truck for house shifting, office moves, and scheduled commercial cargo."
        ),
    },
]


async def seed_sample_vehicles(session: AsyncSession) -> None:
    """Seed public showcase vehicles only if vehicles table is currently empty."""
    count = int((await session.execute(select(func.count(Vehicle.id)))).scalar_one() or 0)
    if count > 0:
        return
    for item in SAMPLE_VEHICLES:
        session.add(Vehicle(**item))
    await session.flush()
