"""Schemas for operational analytics KPIs and dispatch scoring recommendations."""

from uuid import UUID

from pydantic import BaseModel


class ServicePopularityItem(BaseModel):
    """Booking frequency per service category."""

    service_slug: str
    service_name: str
    booking_count: int


class DriverPerformanceItem(BaseModel):
    """Completed trips and average customer rating per driver."""

    driver_id: UUID
    driver_name: str
    completed_trips: int
    average_rating: float | None


class OperationsReportResponse(BaseModel):
    """Aggregated operational, fleet utilization, cancellation, and customer retention KPIs."""

    total_bookings: int
    completed_bookings: int
    cancelled_bookings: int
    cancellation_rate_pct: float
    total_vehicles: int
    busy_or_active_vehicles: int
    vehicle_utilization_pct: float
    repeat_customers: int
    popular_services: list[ServicePopularityItem]
    driver_performance: list[DriverPerformanceItem]


class DispatchRecommendationItem(BaseModel):
    """Scored eligible vehicle/driver candidate for dispatch prioritization."""

    id: UUID
    label: str
    score: int
    reason: str


class DispatchRecommendationsResponse(BaseModel):
    """Top ranked vehicle and driver candidates for a booking."""

    booking_id: UUID
    vehicles: list[DispatchRecommendationItem]
    drivers: list[DispatchRecommendationItem]
