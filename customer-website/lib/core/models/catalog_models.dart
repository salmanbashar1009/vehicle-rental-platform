/// Public transport service category DTO matching FastAPI schema.
class ServiceCategoryDto {
  const ServiceCategoryDto({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.requiresQuote,
    required this.steps,
    required this.extraFields,
    this.imageUrl,
  });

  final String id;
  final String slug;
  final String name;
  final String description;
  final bool requiresQuote;
  final List<String> steps;
  final List<String> extraFields;
  final String? imageUrl;

  String get resolvedImageUrl => imageUrl ?? _defaultServiceImageBySlug(slug);

  static String _defaultServiceImageBySlug(String slug) => switch (slug) {
    'tour_travel' => '/images/svc_tour.jpg',
    'event_transport' => '/images/svc_event.jpg',
    'house_shifting_cargo' => '/images/svc_cargo.jpg',
    'airport_transfer' => '/images/svc_airport.jpg',
    'corporate_transport' => '/images/svc_corporate.jpg',
    'periodic_rental' => '/images/svc_rental.jpg',
    'personal_transport' => '/images/svc_personal.jpg',
    _ => '/images/svc_custom.jpg',
  };

  factory ServiceCategoryDto.fromJson(Map<String, dynamic> json) {
    final wf = json['workflow'] as Map<String, dynamic>?;
    final rawSteps = (wf?['steps_json'] as List<dynamic>?) ?? const [];
    final schema = (wf?['form_schema_json'] as Map<String, dynamic>?) ?? const {};
    final rawFields = (schema['fields'] as List<dynamic>?) ?? const [];
    return ServiceCategoryDto(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      requiresQuote: (json['requires_quote'] as bool?) ?? true,
      steps: rawSteps.map((e) => e.toString()).toList(),
      extraFields: rawFields.map((e) => e.toString()).toList(),
    );
  }
}

/// Public vehicle catalogue DTO matching FastAPI schema.
class VehicleDto {
  const VehicleDto({
    required this.id,
    required this.plateNumber,
    required this.name,
    required this.category,
    required this.make,
    required this.model,
    required this.year,
    required this.seatCapacity,
    required this.luggageCapacity,
    required this.fuelType,
    required this.facilities,
    required this.indicativeDailyRateMinor,
    required this.currency,
    required this.status,
    this.description,
    this.isAvailableForWindow,
    this.primaryImageKey,
  });

  final String id;
  final String plateNumber;
  final String name;
  final String category;
  final String make;
  final String model;
  final int year;
  final int seatCapacity;
  final int luggageCapacity;
  final String fuelType;
  final List<String> facilities;
  final int? indicativeDailyRateMinor;
  final String currency;
  final String status;
  final String? description;
  final bool? isAvailableForWindow;
  final String? primaryImageKey;

  factory VehicleDto.fromJson(Map<String, dynamic> json) {
    final facs = (json['facilities_json'] as List<dynamic>?) ?? const [];
    final imgs = (json['images'] as List<dynamic>?) ?? const [];
    String? imgKey;
    if (imgs.isNotEmpty) {
      final first = imgs.first as Map<String, dynamic>;
      imgKey = first['object_key'] as String?;
    }
    return VehicleDto(
      id: json['id'] as String,
      plateNumber: json['plate_number'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      make: json['make'] as String,
      model: json['model'] as String,
      year: json['year'] as int,
      seatCapacity: json['seat_capacity'] as int,
      luggageCapacity: json['luggage_capacity'] as int,
      fuelType: json['fuel_type'] as String,
      facilities: facs.map((e) => e.toString()).toList(),
      indicativeDailyRateMinor: json['indicative_daily_rate_minor'] as int?,
      currency: (json['currency'] as String?) ?? 'USD',
      status: json['status'] as String,
      description: json['description'] as String?,
      isAvailableForWindow: json['is_available_for_window'] as bool?,
      primaryImageKey: imgKey,
    );
  }

  String get formattedDailyRate {
    if (indicativeDailyRateMinor == null) return 'Custom Quote';
    final major = (indicativeDailyRateMinor! / 100).toStringAsFixed(0);
    return '$currency $major / day';
  }
}
