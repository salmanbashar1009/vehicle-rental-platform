import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import '../../core/config/app_config.dart';
import '../../core/seo/seo_service.dart';

/// SSR Booking Confirmation page showing unique booking reference & next steps.
class BookingConfirmationPage extends StatelessComponent {
  const BookingConfirmationPage({required this.reference, super.key});
  final String reference;

  @override
  Component build(BuildContext context) {
    final seo = SeoMetadata(
      title: 'Booking Confirmation',
      description: 'Booking request confirmation reference $reference.',
      path: '/booking/confirmation/$reference',
      noIndex: true,
    );
    return section(classes: 'vf-section', [
      Document.head(title: '${seo.title} | ${AppConfig.brandName}', children: seo.toHeadComponents()),
      div(classes: 'vf-container vf-card', [
        span(classes: 'vf-badge vf-badge--success', [Component.text('BOOKING CONFIRMATION')]),
        h1([Component.text('Booking Request Confirmed & Queued')]),
        p([
          Component.text('Booking Reference: '),
          strong(classes: 'vf-mono', [Component.text(reference)]),
        ]),
        p(classes: 'vf-muted', [
          Component.text(
            'Your request has been saved. Our dispatch & booking team is verifying vehicle and chauffeur availability and will send your itemized quotation or confirmation shortly.',
          ),
        ]),
        div(styles: Styles(display: Display.flex, flexWrap: FlexWrap.wrap, gap: Gap.all(12.px), margin: Margin.only(top: 16.px)), [
          Link(
            to: '/dashboard/bookings',
            classes: 'vf-btn vf-btn--primary',
            children: [Component.text('View in Customer Portal')],
          ),
          Link(
            to: '/book',
            classes: 'vf-btn vf-btn--outline',
            children: [Component.text('+ Submit Another Request')],
          ),
          Link(
            to: '/',
            classes: 'vf-btn vf-btn--outline',
            children: [Component.text('Return Home')],
          ),
        ]),
      ]),
    ]);
  }
}
