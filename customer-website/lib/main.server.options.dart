// dart format off
// ignore_for_file: type=lint

// GENERATED FILE, DO NOT MODIFY
// Generated with jaspr_builder

import 'package:jaspr/server.dart';
import 'package:velofleet_customer_web/components/layout/site_footer.dart'
    as _site_footer;
import 'package:velofleet_customer_web/components/layout/site_header.dart'
    as _site_header;
import 'package:velofleet_customer_web/components/layout/site_header.styles.dart'
    as _site_header$styles;
import 'package:velofleet_customer_web/features/auth/login_page.dart'
    as _login_page;
import 'package:velofleet_customer_web/features/auth/register_page.dart'
    as _register_page;
import 'package:velofleet_customer_web/features/booking/booking_wizard_page.dart'
    as _booking_wizard_page;
import 'package:velofleet_customer_web/features/catalog/vehicle_detail_page.dart'
    as _vehicle_detail_page;
import 'package:velofleet_customer_web/features/catalog/vehicles_page.dart'
    as _vehicles_page;
import 'package:velofleet_customer_web/features/marketing/contact_page.dart'
    as _contact_page;
import 'package:velofleet_customer_web/features/marketing/home_page.dart'
    as _home_page;
import 'package:velofleet_customer_web/features/marketing/home_page.styles.dart'
    as _home_page$styles;
import 'package:velofleet_customer_web/features/portal/active_trip_tracking_page.dart'
    as _active_trip_tracking_page;
import 'package:velofleet_customer_web/features/portal/customer_booking_detail_page.dart'
    as _customer_booking_detail_page;
import 'package:velofleet_customer_web/features/portal/customer_portal_page.dart'
    as _customer_portal_page;
import 'package:velofleet_customer_web/features/portal/payment_invoice_page.dart'
    as _payment_invoice_page;
import 'package:velofleet_customer_web/features/portal/quotation_detail_page.dart'
    as _quotation_detail_page;
import 'package:velofleet_customer_web/features/portal/review_page.dart'
    as _review_page;

/// Default [ServerOptions] for use with your Jaspr project.
///
/// Use this to initialize Jaspr **before** calling [runApp].
///
/// Example:
/// ```dart
/// import 'main.server.options.dart';
///
/// void main() {
///   Jaspr.initializeApp(
///     options: defaultServerOptions,
///   );
///
///   runApp(...);
/// }
/// ```
ServerOptions get defaultServerOptions => ServerOptions(
  clientId: 'main.client.dart.js',
  clients: {
    _login_page.LoginPage: ClientTarget<_login_page.LoginPage>('login_page'),
    _register_page.RegisterPage: ClientTarget<_register_page.RegisterPage>(
      'register_page',
    ),
    _booking_wizard_page.BookingWizardPage:
        ClientTarget<_booking_wizard_page.BookingWizardPage>(
          'booking_wizard_page',
          params: __booking_wizard_pageBookingWizardPage,
        ),
    _vehicle_detail_page.VehicleDetailPage:
        ClientTarget<_vehicle_detail_page.VehicleDetailPage>(
          'vehicle_detail_page',
          params: __vehicle_detail_pageVehicleDetailPage,
        ),
    _vehicles_page.VehiclesPage: ClientTarget<_vehicles_page.VehiclesPage>(
      'vehicles_page',
    ),
    _contact_page.ContactPage: ClientTarget<_contact_page.ContactPage>(
      'contact_page',
    ),
    _active_trip_tracking_page.ActiveTripTrackingPage:
        ClientTarget<_active_trip_tracking_page.ActiveTripTrackingPage>(
          'active_trip_tracking_page',
          params: __active_trip_tracking_pageActiveTripTrackingPage,
        ),
    _customer_booking_detail_page.CustomerBookingDetailPage:
        ClientTarget<_customer_booking_detail_page.CustomerBookingDetailPage>(
          'customer_booking_detail_page',
          params: __customer_booking_detail_pageCustomerBookingDetailPage,
        ),
    _customer_portal_page.CustomerPortalPage:
        ClientTarget<_customer_portal_page.CustomerPortalPage>(
          'customer_portal_page',
          params: __customer_portal_pageCustomerPortalPage,
        ),
    _payment_invoice_page.PaymentAndInvoicePage:
        ClientTarget<_payment_invoice_page.PaymentAndInvoicePage>(
          'payment_invoice_page',
          params: __payment_invoice_pagePaymentAndInvoicePage,
        ),
    _quotation_detail_page.QuotationDetailPage:
        ClientTarget<_quotation_detail_page.QuotationDetailPage>(
          'quotation_detail_page',
          params: __quotation_detail_pageQuotationDetailPage,
        ),
    _review_page.ReviewSubmissionPage:
        ClientTarget<_review_page.ReviewSubmissionPage>(
          'review_page',
          params: __review_pageReviewSubmissionPage,
        ),
  },
  styles: () => [
    ..._site_header$styles.siteHeaderStyles,
    ..._home_page$styles.homePageStyles,
    ..._site_footer.SiteFooter.styles,
    ..._site_header.SiteHeader.styles,
    ..._home_page.HomePage.styles,
  ],
);

Map<String, Object?> __booking_wizard_pageBookingWizardPage(
  _booking_wizard_page.BookingWizardPage c,
) => {
  'initialService': c.initialService,
  'initialVehicleId': c.initialVehicleId,
};
Map<String, Object?> __vehicle_detail_pageVehicleDetailPage(
  _vehicle_detail_page.VehicleDetailPage c,
) => {'vehicleId': c.vehicleId};
Map<String, Object?> __active_trip_tracking_pageActiveTripTrackingPage(
  _active_trip_tracking_page.ActiveTripTrackingPage c,
) => {'bookingId': c.bookingId};
Map<String, Object?> __customer_booking_detail_pageCustomerBookingDetailPage(
  _customer_booking_detail_page.CustomerBookingDetailPage c,
) => {'bookingId': c.bookingId};
Map<String, Object?> __customer_portal_pageCustomerPortalPage(
  _customer_portal_page.CustomerPortalPage c,
) => {'showHistoryOnly': c.showHistoryOnly};
Map<String, Object?> __payment_invoice_pagePaymentAndInvoicePage(
  _payment_invoice_page.PaymentAndInvoicePage c,
) => {'bookingId': c.bookingId};
Map<String, Object?> __quotation_detail_pageQuotationDetailPage(
  _quotation_detail_page.QuotationDetailPage c,
) => {'quotationId': c.quotationId};
Map<String, Object?> __review_pageReviewSubmissionPage(
  _review_page.ReviewSubmissionPage c,
) => {'bookingId': c.bookingId};
