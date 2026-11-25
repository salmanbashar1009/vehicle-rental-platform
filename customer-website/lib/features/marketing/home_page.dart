import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import '../../components/ui/catalog_cards.dart';
import '../../core/data/default_catalog.dart';
import '../../core/seo/seo_service.dart';
import 'home_page.styles.dart';

/// Public SSR Homepage with realistic fleet hero imagery and service showcase.
class HomePage extends StatelessComponent {
  const HomePage({super.key});

  @override
  Component build(BuildContext context) {
    final seo = SeoMetadata(
      title: 'Chauffeur-Driven Vehicle Rentals & Fleet Dispatch',
      description:
          'Book executive sedans, tour vans, airport transfers, event fleets, and house shifting cargo transport with live operational reliability.',
      path: '/',
      jsonLd: SeoMetadata.organizationJsonLd(),
    );

    return div([
      Document.head(title: '${seo.title} | VeloFleet', children: seo.toHeadComponents()),
      section(classes: 'vf-hero', [
        div(classes: 'vf-container', [
          div(classes: 'vf-hero__grid', [
            div(classes: 'vf-hero__copy', [
              span(classes: 'vf-badge vf-badge--warning', [
                Component.text('CHAUFFEUR-DRIVEN · ZERO DOUBLE-BOOKING'),
              ]),
              h1([Component.text('Premium Chauffeur & Fleet Mobility for Every Journey')]),
              p(classes: 'vf-hero__lead', [
                Component.text(
                  'From punctual airport transfers and executive commutes to multi-day tours, gala events, and dedicated cargo shifting — dispatched with verified chauffeurs and live trip visibility.',
                ),
              ]),
              div(classes: 'vf-hero__cta-row', [
                Link(
                  to: '/book',
                  classes: 'vf-btn vf-btn--secondary',
                  children: [Component.text('Request a Booking / Quote')],
                ),
                Link(
                  to: '/vehicles',
                  classes: 'vf-btn vf-btn--ghost-light',
                  children: [Component.text('Explore Fleet Catalogue')],
                ),
              ]),
            ]),
            div(classes: 'vf-hero__visual', [
              img(
                classes: 'vf-hero__image',
                src: '/images/hero_fleet.jpg',
                alt: 'Luxury chauffeur-driven executive sedan parked at modern glass hotel plaza',
              ),
              div(classes: 'vf-hero__float-pill', [
                Component.text('24/7 Live Dispatch · Dedicated Executive Sedans, Tour Vans & Cargo'),
              ]),
            ]),
          ]),
          div(classes: 'vf-hero__metrics', [
            _metric('8 Core Services', 'Tours, Events, Cargo, Airport & Corporate'),
            _metric('Verified Chauffeurs', 'Licensed, background-checked & customer-rated'),
            _metric('Atomic Reservations', 'Database-locked scheduling prevents clashes'),
            _metric('Itemized Billing', 'Transparent quotes, invoices & online statements'),
          ]),
        ]),
      ]),
      section(classes: 'vf-section', [
        div(classes: 'vf-container', [
          div(classes: 'vf-section-head', [
            div([
              h2([Component.text('Transportation Services')]),
              p(classes: 'vf-muted', [
                Component.text('Purpose-matched vehicles and trained chauffeurs for passengers, events, and cargo.'),
              ]),
            ]),
            Link(
              to: '/services',
              classes: 'vf-btn vf-btn--outline',
              children: [Component.text('View All 8 Services →')],
            ),
          ]),
          div(classes: 'vf-grid-3', [
            for (final svc in ServiceCatalogReference.categories.take(6))
              ServiceCard(service: svc),
          ]),
        ]),
      ]),
      section(classes: 'vf-section', styles: Styles(padding: Padding.only(top: 0.px)), [
        div(classes: 'vf-container vf-card', [
          h2([Component.text('Why Teams & Families Choose VeloFleet')]),
          div(classes: 'vf-grid-3', [
            _pillar('Guaranteed Availability', 'Confirmed bookings reserve vehicles atomically to prevent scheduling clashes.'),
            _pillar('Itemized Quotations', 'Clear line-by-line pricing, deposit expectations, and validity timelines.'),
            _pillar('Customer Self-Service', 'Track active trips live, manage quotations, and download PDF invoices online.'),
          ]),
        ]),
      ]),
    ]);
  }

  Component _metric(String title, String subtitle) => div(classes: 'vf-hero__metric', [
    strong([Component.text(title)]),
    p(styles: Styles(fontSize: 0.875.rem, margin: Margin.only(top: 6.px, bottom: 0.px)), [
      Component.text(subtitle),
    ]),
  ]);

  Component _pillar(String title, String body) => div([
    h3([Component.text(title)]),
    p(classes: 'vf-muted', [Component.text(body)]),
  ]);

  @css
  static List<StyleRule> get styles => homePageStyles;
}
