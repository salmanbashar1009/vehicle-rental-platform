import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import 'components/layout/site_footer.dart';
import 'components/layout/site_header.dart';
import 'features/auth/login_page.dart';
import 'features/auth/register_page.dart';
import 'features/booking/booking_confirmation_page.dart';
import 'features/booking/booking_wizard_page.dart';
import 'features/catalog/services_pages.dart';
import 'features/catalog/vehicle_detail_page.dart';
import 'features/catalog/vehicles_page.dart';
import 'features/marketing/contact_page.dart';
import 'features/marketing/home_page.dart';
import 'features/marketing/info_pages.dart';
import 'features/portal/active_trip_tracking_page.dart';
import 'features/portal/customer_booking_detail_page.dart';
import 'features/portal/customer_portal_page.dart';
import 'features/portal/payment_invoice_page.dart';
import 'features/portal/quotation_detail_page.dart';
import 'features/portal/review_page.dart';

/// Root Jaspr application shell and multi-page route table.
class App extends StatelessComponent {
  const App({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'vf-app', [
      const SiteHeader(),
      main_(classes: 'vf-main', [
        Router(
          routes: [
            Route(path: '/', title: 'Home', builder: (_, _) => const HomePage()),
            Route(path: '/about', title: 'About', builder: (_, _) => const AboutPage()),
            Route(path: '/services', title: 'Services', builder: (_, _) => const ServicesPage()),
            Route(
              path: '/services/:slug',
              title: 'Service Details',
              builder: (_, state) => ServiceDetailPage(slug: state.params['slug'] ?? ''),
            ),
            Route(path: '/vehicles', title: 'Fleet', builder: (_, _) => const VehiclesPage()),
            Route(
              path: '/vehicles/:id',
              title: 'Vehicle Details',
              builder: (_, state) => VehicleDetailPage(vehicleId: state.params['id'] ?? ''),
            ),
            Route(
              path: '/book',
              title: 'Book',
              builder: (_, state) => BookingWizardPage(
                initialService: state.queryParams['service'],
                initialVehicleId: state.queryParams['vehicle_id'],
              ),
            ),
            Route(
              path: '/booking/confirmation/:ref',
              title: 'Confirmation',
              builder: (_, state) => BookingConfirmationPage(reference: state.params['ref'] ?? ''),
            ),
            Route(path: '/login', title: 'Sign In', builder: (_, _) => const LoginPage()),
            Route(path: '/register', title: 'Register', builder: (_, _) => const RegisterPage()),
            Route(path: '/dashboard', title: 'Dashboard', builder: (_, _) => const CustomerPortalPage()),
            Route(
              path: '/dashboard/bookings',
              title: 'Booking History',
              builder: (_, _) => const CustomerPortalPage(showHistoryOnly: true),
            ),
            Route(
              path: '/dashboard/bookings/:id',
              title: 'Booking Detail',
              builder: (_, state) => CustomerBookingDetailPage(bookingId: state.params['id'] ?? ''),
            ),
            Route(
              path: '/dashboard/track/:id',
              title: 'Live Tracking',
              builder: (_, state) => ActiveTripTrackingPage(bookingId: state.params['id'] ?? ''),
            ),
            Route(
              path: '/dashboard/quotations/:id',
              title: 'Quotation Details',
              builder: (_, state) => QuotationDetailPage(quotationId: state.params['id'] ?? ''),
            ),
            Route(
              path: '/dashboard/payments/:id',
              title: 'Payments & Invoices',
              builder: (_, state) => PaymentAndInvoicePage(bookingId: state.params['id'] ?? ''),
            ),
            Route(
              path: '/dashboard/reviews/:id',
              title: 'Leave a Review',
              builder: (_, state) => ReviewSubmissionPage(bookingId: state.params['id'] ?? ''),
            ),
            Route(path: '/contact', title: 'Contact', builder: (_, _) => const ContactPage()),
            Route(path: '/faq', title: 'FAQ', builder: (_, _) => const FaqPage()),
            Route(path: '/legal/terms', title: 'Terms', builder: (_, _) => const LegalPage(kind: 'terms')),
            Route(path: '/legal/privacy', title: 'Privacy', builder: (_, _) => const LegalPage(kind: 'privacy')),
            Route(
              path: '/legal/cancellation',
              title: 'Cancellation',
              builder: (_, _) => const LegalPage(kind: 'cancellation'),
            ),
          ],
          errorBuilder: (_, _) => const NotFoundPage(),
        ),
      ]),
      const SiteFooter(),
    ]);
  }
}
