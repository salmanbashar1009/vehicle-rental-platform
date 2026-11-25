import '../models/catalog_models.dart';

/// Canonical metadata for the 8 supported service categories used during SSR & offline fallback.
class ServiceCatalogReference {
  const ServiceCatalogReference._();

  static const List<ServiceCategoryDto> categories = [
    ServiceCategoryDto(
      id: 'svc-tour',
      slug: 'tour_travel',
      name: 'Tour & Travel',
      description: 'Multi-destination guided chauffeur journeys with flexible stops and overnight stays.',
      requiresQuote: true,
      steps: ['assigned', 'en_route_to_pickup', 'arrived_at_pickup', 'picked_up', 'journey_started', 'at_destination', 'service_completed'],
      extraFields: ['destinations_summary', 'overnight_stay', 'itinerary_notes'],
    ),
    ServiceCategoryDto(
      id: 'svc-event',
      slug: 'event_transport',
      name: 'Event Transportation',
      description: 'Coordinated group and VIP arrivals for weddings, conferences, and private galas.',
      requiresQuote: true,
      steps: ['assigned', 'en_route_to_pickup', 'arrived_at_pickup', 'picked_up', 'journey_started', 'at_destination', 'service_completed'],
      extraFields: ['event_venue', 'return_trip_required'],
    ),
    ServiceCategoryDto(
      id: 'svc-cargo',
      slug: 'house_shifting_cargo',
      name: 'House Shifting & Cargo',
      description: 'Dedicated cargo vans and box trucks with optional loading and unloading support.',
      requiresQuote: true,
      steps: ['assigned', 'en_route_to_pickup', 'arrived_at_pickup', 'loading_started', 'loading_completed', 'picked_up', 'journey_started', 'at_destination', 'unloading_started', 'unloading_completed', 'service_completed'],
      extraFields: ['cargo_volume', 'pickup_floor', 'dropoff_floor', 'has_elevator', 'needs_crew'],
    ),
    ServiceCategoryDto(
      id: 'svc-airport',
      slug: 'airport_transfer',
      name: 'Airport Transfer',
      description: 'Punctual terminal pickup and drop-off with flight tracking and luggage handling.',
      requiresQuote: false,
      steps: ['assigned', 'en_route_to_pickup', 'arrived_at_pickup', 'picked_up', 'journey_started', 'at_destination', 'service_completed'],
      extraFields: ['flight_number', 'terminal', 'transfer_direction'],
    ),
    ServiceCategoryDto(
      id: 'svc-corp',
      slug: 'corporate_transport',
      name: 'Corporate Transportation',
      description: 'Executive mobility, recurring office commutes, and consolidated corporate invoicing.',
      requiresQuote: true,
      steps: ['assigned', 'en_route_to_pickup', 'arrived_at_pickup', 'picked_up', 'journey_started', 'at_destination', 'service_completed'],
      extraFields: ['company_name', 'cost_center', 'recurring_schedule'],
    ),
    ServiceCategoryDto(
      id: 'svc-rental',
      slug: 'periodic_rental',
      name: 'Daily, Weekly & Monthly Rental',
      description: 'Chauffeur-driven short and long-term vehicle allocations with transparent mileage policies.',
      requiresQuote: true,
      steps: ['assigned', 'en_route_to_pickup', 'arrived_at_pickup', 'picked_up', 'journey_started', 'at_destination', 'service_completed'],
      extraFields: ['rental_period_type', 'estimated_daily_km'],
    ),
    ServiceCategoryDto(
      id: 'svc-personal',
      slug: 'personal_transport',
      name: 'Personal Transportation',
      description: 'Comfortable point-to-point or hourly private chauffeur rides tailored to your schedule.',
      requiresQuote: false,
      steps: ['assigned', 'en_route_to_pickup', 'arrived_at_pickup', 'picked_up', 'journey_started', 'at_destination', 'service_completed'],
      extraFields: ['special_requests'],
    ),
    ServiceCategoryDto(
      id: 'svc-custom',
      slug: 'custom_service',
      name: 'Customized Service',
      description: 'Bespoke multi-vehicle or specialized transportation tailored to unique requirements.',
      requiresQuote: true,
      steps: ['assigned', 'en_route_to_pickup', 'arrived_at_pickup', 'picked_up', 'journey_started', 'at_destination', 'service_completed'],
      extraFields: ['custom_requirements'],
    ),
  ];

  static ServiceCategoryDto? findBySlug(String slug) {
    for (final cat in categories) {
      if (cat.slug == slug) return cat;
    }
    return null;
  }
}
