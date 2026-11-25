// dart format off
// ignore_for_file: type=lint

// GENERATED FILE, DO NOT MODIFY
// Generated with jaspr_builder

import 'package:jaspr/client.dart';

import 'package:velofleet_customer_web/features/auth/login_page.dart'
    deferred as _login_page;
import 'package:velofleet_customer_web/features/auth/register_page.dart'
    deferred as _register_page;
import 'package:velofleet_customer_web/features/booking/booking_wizard_page.dart'
    deferred as _booking_wizard_page;
import 'package:velofleet_customer_web/features/catalog/vehicle_detail_page.dart'
    deferred as _vehicle_detail_page;
import 'package:velofleet_customer_web/features/catalog/vehicles_page.dart'
    deferred as _vehicles_page;
import 'package:velofleet_customer_web/features/marketing/contact_page.dart'
    deferred as _contact_page;
import 'package:velofleet_customer_web/features/portal/active_trip_tracking_page.dart'
    deferred as _active_trip_tracking_page;
import 'package:velofleet_customer_web/features/portal/customer_booking_detail_page.dart'
    deferred as _customer_booking_detail_page;
import 'package:velofleet_customer_web/features/portal/customer_portal_page.dart'
    deferred as _customer_portal_page;
import 'package:velofleet_customer_web/features/portal/payment_invoice_page.dart'
    deferred as _payment_invoice_page;
import 'package:velofleet_customer_web/features/portal/quotation_detail_page.dart'
    deferred as _quotation_detail_page;
import 'package:velofleet_customer_web/features/portal/review_page.dart'
    deferred as _review_page;

/// Default [ClientOptions] for use with your Jaspr project.
///
/// Use this to initialize Jaspr **before** calling [runApp].
///
/// Example:
/// ```dart
/// import 'main.client.options.dart';
///
/// void main() {
///   Jaspr.initializeApp(
///     options: defaultClientOptions,
///   );
///
///   runApp(...);
/// }
/// ```
ClientOptions get defaultClientOptions => ClientOptions(
  clients: {
    'login_page': ClientLoader(
      (p) => _login_page.LoginPage(),
      loader: _login_page.loadLibrary,
    ),
    'register_page': ClientLoader(
      (p) => _register_page.RegisterPage(),
      loader: _register_page.loadLibrary,
    ),
    'booking_wizard_page': ClientLoader(
      (p) => _booking_wizard_page.BookingWizardPage(
        initialService: p['initialService'] as String?,
        initialVehicleId: p['initialVehicleId'] as String?,
      ),
      loader: _booking_wizard_page.loadLibrary,
    ),
    'vehicle_detail_page': ClientLoader(
      (p) => _vehicle_detail_page.VehicleDetailPage(
        vehicleId: p['vehicleId'] as String,
      ),
      loader: _vehicle_detail_page.loadLibrary,
    ),
    'vehicles_page': ClientLoader(
      (p) => _vehicles_page.VehiclesPage(),
      loader: _vehicles_page.loadLibrary,
    ),
    'contact_page': ClientLoader(
      (p) => _contact_page.ContactPage(),
      loader: _contact_page.loadLibrary,
    ),
    'active_trip_tracking_page': ClientLoader(
      (p) => _active_trip_tracking_page.ActiveTripTrackingPage(
        bookingId: p['bookingId'] as String,
      ),
      loader: _active_trip_tracking_page.loadLibrary,
    ),
    'customer_booking_detail_page': ClientLoader(
      (p) => _customer_booking_detail_page.CustomerBookingDetailPage(
        bookingId: p['bookingId'] as String,
      ),
      loader: _customer_booking_detail_page.loadLibrary,
    ),
    'customer_portal_page': ClientLoader(
      (p) => _customer_portal_page.CustomerPortalPage(
        showHistoryOnly: p['showHistoryOnly'] as bool,
      ),
      loader: _customer_portal_page.loadLibrary,
    ),
    'payment_invoice_page': ClientLoader(
      (p) => _payment_invoice_page.PaymentAndInvoicePage(
        bookingId: p['bookingId'] as String,
      ),
      loader: _payment_invoice_page.loadLibrary,
    ),
    'quotation_detail_page': ClientLoader(
      (p) => _quotation_detail_page.QuotationDetailPage(
        quotationId: p['quotationId'] as String,
      ),
      loader: _quotation_detail_page.loadLibrary,
    ),
    'review_page': ClientLoader(
      (p) => _review_page.ReviewSubmissionPage(
        bookingId: p['bookingId'] as String,
      ),
      loader: _review_page.loadLibrary,
    ),
  },
);
