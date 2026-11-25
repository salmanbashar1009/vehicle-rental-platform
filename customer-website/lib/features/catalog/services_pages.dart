import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import '../../components/ui/catalog_cards.dart';
import '../../core/config/app_config.dart';
import '../../core/data/default_catalog.dart';
import '../../core/seo/seo_service.dart';

/// SSR Services Directory displaying all 8 business transport categories.
class ServicesPage extends StatelessComponent {
  const ServicesPage({super.key});

  @override
  Component build(BuildContext context) {
    final seo = SeoMetadata(
      title: 'Transportation Services',
      description: 'Explore all 8 chauffeur-driven services: tours, events, house shifting, airport transfers, corporate, daily/monthly rentals, personal & custom.',
      path: '/services',
    );
    return section(classes: 'vf-section', [
      Document.head(title: '${seo.title} | ${AppConfig.brandName}', children: seo.toHeadComponents()),
      div(classes: 'vf-container', [
        h1([Component.text('Our Transportation Services')]),
        p(classes: 'vf-muted', [
          Component.text('Every service category supports tailored itineraries, transparent pricing, and vetted chauffeurs.'),
        ]),
        div(classes: 'vf-grid-3', [
          for (final svc in ServiceCatalogReference.categories) ServiceCard(service: svc),
        ]),
      ]),
    ]);
  }
}

/// SSR Service Details page with workflow milestones and direct booking CTA.
class ServiceDetailPage extends StatelessComponent {
  const ServiceDetailPage({required this.slug, super.key});
  final String slug;

  @override
  Component build(BuildContext context) {
    final svc = ServiceCatalogReference.findBySlug(slug);
    if (svc == null) {
      return section(classes: 'vf-section', [
        div(classes: 'vf-container vf-card', [
          h1([Component.text('Service Not Found')]),
          Link(to: '/services', classes: 'vf-btn vf-btn--primary', children: [Component.text('All Services')]),
        ]),
      ]);
    }
    final seo = SeoMetadata(
      title: svc.name,
      description: svc.description,
      path: '/services/${svc.slug}',
      jsonLd: SeoMetadata.serviceJsonLd(name: svc.name, description: svc.description, slug: svc.slug),
    );
    return section(classes: 'vf-section', [
      Document.head(title: '${seo.title} | ${AppConfig.brandName}', children: seo.toHeadComponents()),
      div(classes: 'vf-container vf-card', [
        img(
          classes: 'vf-card__media',
          src: svc.resolvedImageUrl,
          alt: '${svc.name} fleet vehicle',
          styles: Styles(margin: Margin.only(bottom: 20.px), radius: BorderRadius.circular(12.px)),
        ),
        span(classes: 'vf-badge vf-badge--info', [
          Component.text(svc.requiresQuote ? 'Admin Quotation Workflow' : 'Fast Booking Eligible'),
        ]),
        h1([Component.text(svc.name)]),
        p([Component.text(svc.description)]),
        h2([Component.text('Operational Milestones')]),
        ol([
          for (final step in svc.steps)
            li([Component.text(step.replaceAll('_', ' ').toUpperCase())]),
        ]),
        div(styles: Styles(display: Display.flex, gap: Gap.all(12.px), margin: Margin.only(top: 20.px)), [
          Link(
            to: '/book?service=${svc.slug}',
            classes: 'vf-btn vf-btn--primary',
            children: [Component.text('Book ${svc.name}')],
          ),
          Link(
            to: '/vehicles',
            classes: 'vf-btn vf-btn--outline',
            children: [Component.text('Browse Eligible Vehicles')],
          ),
        ]),
      ]),
    ]);
  }
}
