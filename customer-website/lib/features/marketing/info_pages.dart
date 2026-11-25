import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import '../../core/config/app_config.dart';
import '../../core/seo/seo_service.dart';

/// SSR About Us page.
class AboutPage extends StatelessComponent {
  const AboutPage({super.key});

  @override
  Component build(BuildContext context) {
    final seo = SeoMetadata(
      title: 'About Us',
      description: 'Learn about VeloFleet chauffeur standards, maintained fleet operations, and safety commitments.',
      path: '/about',
    );
    return section(classes: 'vf-section', [
      Document.head(title: '${seo.title} | ${AppConfig.brandName}', children: seo.toHeadComponents()),
      div(classes: 'vf-container vf-card', [
        h1([Component.text('About ${AppConfig.brandName}')]),
        p([
          Component.text(
            '${AppConfig.brandName} operates a centralized chauffeur-driven transportation fleet serving individuals, families, event planners, and corporate organizations.',
          ),
        ]),
        div(classes: 'vf-grid-3', [
          _box('Preventive Fleet Care', 'Every vehicle passes scheduled maintenance and compliance document checks before dispatch.'),
          _box('Licensed Chauffeurs', 'Drivers undergo licence verification, safety briefings, and operational milestone training.'),
          _box('Privacy-Respecting Tracking', 'Live GPS sharing activates strictly during authorized active trips and terminates upon completion.'),
        ]),
      ]),
    ]);
  }

  Component _box(String title, String copy) => div(classes: 'vf-card', [
    h3([Component.text(title)]),
    p(classes: 'vf-muted', [Component.text(copy)]),
  ]);
}

/// SSR Frequently Asked Questions page with FAQPage JSON-LD.
class FaqPage extends StatelessComponent {
  const FaqPage({super.key});

  static const _faqs = [
    ('Can I request a booking without creating an account first?', 'Yes. You can submit an enquiry with your contact details and receive a unique booking reference immediately.'),
    ('How are quotations calculated and confirmed?', 'Certain point-to-point services offer indicative estimates, while multi-day tours, events, and cargo moves receive an itemized admin quotation with a validity period.'),
    ('When is live trip tracking visible?', 'Live vehicle location is shared only with the booking owner during an active assigned trip when tracking is enabled.'),
    ('What happens if I need to reschedule or cancel?', 'Rescheduling depends on vehicle and driver availability; cancellations follow the terms stated on your quotation and our Cancellation Policy.'),
  ];

  @override
  Component build(BuildContext context) {
    final seo = SeoMetadata(
      title: 'Frequently Asked Questions',
      description: 'Answers on booking requests, itemized quotations, chauffeur assignments, live tracking, and cancellations.',
      path: '/faq',
      jsonLd: {
        '@context': 'https://schema.org',
        '@type': 'FAQPage',
        'mainEntity': [
          for (final (q, a) in _faqs)
            {'@type': 'Question', 'name': q, 'acceptedAnswer': {'@type': 'Answer', 'text': a}},
        ],
      },
    );
    return section(classes: 'vf-section', [
      Document.head(title: '${seo.title} | ${AppConfig.brandName}', children: seo.toHeadComponents()),
      div(classes: 'vf-container', [
        h1([Component.text('Frequently Asked Questions')]),
        for (final (q, a) in _faqs)
          div(classes: 'vf-card', styles: Styles(margin: Margin.only(bottom: 14.px)), [
            h3([Component.text(q)]),
            p(classes: 'vf-muted', [Component.text(a)]),
          ]),
      ]),
    ]);
  }
}

/// Reusable SSR Legal policy page (Terms, Privacy, Cancellation).
class LegalPage extends StatelessComponent {
  const LegalPage({required this.kind, super.key});
  final String kind;

  @override
  Component build(BuildContext context) {
    final (title, path, summary) = switch (kind) {
      'privacy' => (
        'Privacy Policy',
        '/legal/privacy',
        'We collect only the customer, booking, and authorized active-trip location data required to deliver safe chauffeur services. GPS data is retained per configured retention policy and never sold.',
      ),
      'cancellation' => (
        'Cancellation Policy',
        '/legal/cancellation',
        'Cancellation eligibility and applicable charges depend on the timing before scheduled pickup and the specific terms agreed in your confirmed quotation.',
      ),
      _ => (
        'Terms & Conditions',
        '/legal/terms',
        'All chauffeur-driven rentals are subject to confirmed vehicle/driver availability, valid quotation acceptance, and compliance with safety policies.',
      ),
    };
    final seo = SeoMetadata(title: title, description: summary, path: path);
    return section(classes: 'vf-section', [
      Document.head(title: '$title | ${AppConfig.brandName}', children: seo.toHeadComponents()),
      div(classes: 'vf-container vf-card', [
        h1([Component.text(title)]),
        p([Component.text(summary)]),
        p(classes: 'vf-muted', [
          Component.text('Questions? Contact ${AppConfig.supportEmail} or ${AppConfig.supportPhone}.'),
        ]),
      ]),
    ]);
  }
}

/// 404 Not Found page.
class NotFoundPage extends StatelessComponent {
  const NotFoundPage({super.key});

  @override
  Component build(BuildContext context) {
    return section(classes: 'vf-section', [
      Document.head(title: 'Page Not Found | ${AppConfig.brandName}'),
      div(classes: 'vf-container vf-card', [
        h1([Component.text('404 — Page Not Found')]),
        p(classes: 'vf-muted', [Component.text('The page you requested could not be found.')]),
        div(styles: Styles(display: Display.flex, gap: Gap.all(10.px)), [
          Link(to: '/', classes: 'vf-btn vf-btn--primary', children: [Component.text('Back to Home')]),
          Link(to: '/vehicles', classes: 'vf-btn vf-btn--outline', children: [Component.text('Browse Fleet')]),
        ]),
      ]),
    ]);
  }
}
