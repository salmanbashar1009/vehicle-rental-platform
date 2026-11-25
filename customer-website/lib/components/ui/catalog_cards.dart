import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import '../../core/models/catalog_models.dart';
import 'ui_primitives.dart';

/// Reusable service category card with realistic vehicle photography and conversion CTAs.
class ServiceCard extends StatelessComponent {
  const ServiceCard({required this.service, super.key});

  final ServiceCategoryDto service;

  @override
  Component build(BuildContext context) {
    return article(classes: 'vf-card vf-card--interactive', [
      img(
        classes: 'vf-card__media',
        src: service.resolvedImageUrl,
        alt: '${service.name} chauffeur vehicle',
      ),
      div(classes: 'vf-card__body', [
        div(
          styles: Styles(
            alignItems: AlignItems.center,
            display: Display.flex,
            justifyContent: JustifyContent.spaceBetween,
            margin: Margin.only(bottom: 10.px),
          ),
          [
            span(classes: 'vf-badge vf-badge--info', [
              Component.text(service.requiresQuote ? 'Custom Quote' : 'Instant / Express'),
            ]),
          ],
        ),
        h3([Component.text(service.name)]),
        p(classes: 'vf-muted', [Component.text(service.description)]),
        div(classes: 'vf-card__footer', [
          Link(
            to: '/services/${service.slug}',
            classes: 'vf-btn vf-btn--outline',
            children: [Component.text('Details')],
          ),
          Link(
            to: '/book?service=${service.slug}',
            classes: 'vf-btn vf-btn--primary',
            children: [Component.text('Request Quote')],
          ),
        ]),
      ]),
    ]);
  }
}

/// Reusable vehicle card showing vehicle photograph, capacity, facilities, and rate.
class VehicleCard extends StatelessComponent {
  const VehicleCard({required this.vehicle, super.key});

  final VehicleDto vehicle;

  String get _fallbackPhoto => switch (vehicle.category.toLowerCase()) {
    'van' || 'minivan' || 'bus' => '/images/svc_tour.jpg',
    'truck' || 'cargo' || 'pickup' => '/images/svc_cargo.jpg',
    'suv' => '/images/svc_rental.jpg',
    _ => '/images/svc_corporate.jpg',
  };

  @override
  Component build(BuildContext context) {
    return article(classes: 'vf-card vf-card--interactive', [
      img(
        classes: 'vf-card__media',
        src: _fallbackPhoto,
        alt: '${vehicle.make} ${vehicle.model}',
      ),
      div(classes: 'vf-card__body', [
        div(
          styles: Styles(
            alignItems: AlignItems.center,
            display: Display.flex,
            justifyContent: JustifyContent.spaceBetween,
            margin: Margin.only(bottom: 8.px),
          ),
          [
            span(classes: 'vf-badge vf-badge--info', [
              Component.text(vehicle.category.toUpperCase()),
            ]),
            StatusBadge(
              status: vehicle.isAvailableForWindow == false ? 'reserved' : vehicle.status,
            ),
          ],
        ),
        h3([Component.text(vehicle.name)]),
        p(classes: 'vf-muted', [
          Component.text('${vehicle.make} ${vehicle.model} (${vehicle.year}) · ${vehicle.fuelType}'),
        ]),
        p([
          Component.text(
            '${vehicle.seatCapacity} Seats · ${vehicle.luggageCapacity} Luggage · ${vehicle.facilities.take(3).join(', ')}',
          ),
        ]),
        p(
          styles: Styles(color: Color('var(--color-primary-700)'), fontWeight: FontWeight.w700),
          [Component.text(vehicle.formattedDailyRate)],
        ),
        div(classes: 'vf-card__footer', [
          Link(
            to: '/vehicles/${vehicle.id}',
            classes: 'vf-btn vf-btn--outline',
            children: [Component.text('View Specs')],
          ),
          Link(
            to: '/book?vehicle_id=${vehicle.id}',
            classes: 'vf-btn vf-btn--primary',
            children: [Component.text('Book Vehicle')],
          ),
        ]),
      ]),
    ]);
  }
}
