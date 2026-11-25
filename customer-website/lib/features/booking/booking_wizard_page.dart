import 'dart:convert';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../components/ui/ui_primitives.dart';
import '../../core/auth/auth_session.dart';
import '../../core/config/app_config.dart';
import '../../core/data/default_catalog.dart';
import '../../core/http/api_client.dart';
import '../../core/http/api_error.dart';
import '../../core/models/booking_models.dart';
import '../../core/web/browser_nav.dart';
import 'booking_confirmation_page.dart';
import 'booking_guest_fields.dart';
import 'booking_payload_builder.dart';
import 'booking_stop_fields.dart';

/// Multi-stop Booking / Quote Request Wizard supporting all 8 service types.
@client
class BookingWizardPage extends StatefulComponent {
  const BookingWizardPage({this.initialService, this.initialVehicleId, super.key});
  final String? initialService;
  final String? initialVehicleId;

  @override
  State<BookingWizardPage> createState() => _BookingWizardPageState();
}

class _BookingWizardPageState extends State<BookingWizardPage> {
  late String _serviceSlug =
      ServiceCatalogReference.findBySlug(component.initialService ?? '')?.slug ?? 'airport_transfer';
  String? _lastPayloadJson;
  String _idempotencyKey = generateUuidV4();
  String _pickupAddress = '';
  String _destinationAddress = '';
  final List<String> _waypoints = [];
  String _pickupAt = '2026-12-01T09:00';
  String _expectedEndAt = '2026-12-01T13:00';
  String _passengers = '2';
  String _luggage = '2';
  String _customerName = '';
  String _customerEmail = '';
  String _customerPhone = '';
  String _notes = '';
  final Map<String, String> _extraMeta = {};
  bool _submitting = false;
  String? _error;
  BookingDto? _confirmedBooking;

  Future<void> _submit() async {
    final auth = CustomerAuthStore.instance;
    final Map<String, dynamic> payload;
    try {
      payload = buildBookingRequestPayload(
        serviceSlug: _serviceSlug,
        preferredVehicleId: component.initialVehicleId,
        pickupAtRaw: _pickupAt,
        expectedEndAtRaw: _expectedEndAt,
        passengersRaw: _passengers,
        luggageRaw: _luggage,
        pickupAddress: _pickupAddress,
        destinationAddress: _destinationAddress,
        waypoints: _waypoints,
        extraMeta: _extraMeta,
        notes: _notes,
        isAuthenticated: auth.isAuthenticated,
        customerName: _customerName,
        customerEmail: _customerEmail,
        customerPhone: _customerPhone,
      );
    } on FormatException catch (e) {
      setState(() => _error = e.message);
      return;
    }

    final payloadJson = jsonEncode(payload);
    if (_lastPayloadJson != payloadJson) {
      _lastPayloadJson = payloadJson;
      _idempotencyKey = generateUuidV4();
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final res = await auth.api.post(
        '/bookings',
        idempotencyKey: _idempotencyKey,
        body: payload,
      ) as Map<String, dynamic>;
      final created = BookingDto.fromJson(res);
      if (!mounted) return;
      setState(() {
        _confirmedBooking = created;
        _submitting = false;
      });
      navigateTo(context, '/booking/confirmation/${created.reference}');
    } on ApiError catch (e) {
      setState(() {
        _error = '${e.message}${e.correlationId != null ? ' (Ref: ${e.correlationId})' : ''}';
        _submitting = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Unable to submit booking request. Please check your connection and try again.';
        _submitting = false;
      });
    }
  }

  @override
  Component build(BuildContext context) {
    if (_confirmedBooking != null) {
      return BookingConfirmationPage(reference: _confirmedBooking!.reference);
    }
    final svc = ServiceCatalogReference.findBySlug(_serviceSlug) ??
        ServiceCatalogReference.categories.first;
    final auth = CustomerAuthStore.instance;
    return section(classes: 'vf-section', [
      Document.head(title: 'Request Booking or Quote | ${AppConfig.brandName}'),
      div(classes: 'vf-container', [
        div(classes: 'vf-card', [
          h1([Component.text('Request a Booking or Quotation')]),
          p(classes: 'vf-muted', [
            Component.text('Every request receives an instant booking confirmation reference and availability check.'),
          ]),
          if (_error != null) ErrorBanner(message: _error!),
          div(classes: 'vf-grid-2', [
            div(classes: 'vf-field', [
              label(classes: 'vf-label', htmlFor: 'bk-svc', [Component.text('Service Category')]),
              select(
                id: 'bk-svc',
                classes: 'vf-select',
                onChange: (vals) => setState(() {
                  if (vals.isNotEmpty) _serviceSlug = vals.first;
                }),
                [
                  for (final cat in ServiceCatalogReference.categories)
                    option(value: cat.slug, selected: cat.slug == _serviceSlug, [Component.text(cat.name)]),
                ],
              ),
            ]),
            div(classes: 'vf-field', [
              label(classes: 'vf-label', htmlFor: 'bk-pax', [Component.text('Passengers / Luggage')]),
              div(styles: Styles(display: Display.flex, gap: Gap.all(10.px)), [
                input(id: 'bk-pax', classes: 'vf-input', type: InputType.number, value: _passengers, onInput: (v) => _passengers = v.toString()),
                input(id: 'bk-lug', classes: 'vf-input', type: InputType.number, value: _luggage, onInput: (v) => _luggage = v.toString()),
              ]),
            ]),
            div(classes: 'vf-field', [
              label(classes: 'vf-label', htmlFor: 'bk-start', [Component.text('Pickup Date & Time (UTC)')]),
              input(id: 'bk-start', classes: 'vf-input', type: InputType.dateTimeLocal, value: _pickupAt, onInput: (v) => _pickupAt = v.toString()),
            ]),
            div(classes: 'vf-field', [
              label(classes: 'vf-label', htmlFor: 'bk-end', [Component.text('Expected Return / End (UTC)')]),
              input(id: 'bk-end', classes: 'vf-input', type: InputType.dateTimeLocal, value: _expectedEndAt, onInput: (v) => _expectedEndAt = v.toString()),
            ]),
          ]),
          BookingStopsSection(
            pickupAddress: _pickupAddress,
            destinationAddress: _destinationAddress,
            waypoints: _waypoints,
            onPickupChanged: (v) => _pickupAddress = v,
            onDestinationChanged: (v) => _destinationAddress = v,
            onAddWaypoint: () => setState(() => _waypoints.add('')),
            onRemoveWaypoint: (idx) => setState(() => _waypoints.removeAt(idx)),
            onUpdateWaypoint: (idx, v) => _waypoints[idx] = v,
          ),
          for (final fieldName in svc.extraFields)
            div(classes: 'vf-field', [
              label(classes: 'vf-label', [Component.text(fieldName.replaceAll('_', ' ').toUpperCase())]),
              input(classes: 'vf-input', value: _extraMeta[fieldName] ?? '', onInput: (v) => _extraMeta[fieldName] = v.toString()),
            ]),
          if (!auth.isAuthenticated)
            BookingGuestContactSection(
              name: _customerName,
              email: _customerEmail,
              phone: _customerPhone,
              onNameChanged: (v) => _customerName = v,
              onEmailChanged: (v) => _customerEmail = v,
              onPhoneChanged: (v) => _customerPhone = v,
            ),
          div(classes: 'vf-field', [
            label(classes: 'vf-label', htmlFor: 'bk-notes', [Component.text('Special Requirements & Notes')]),
            textarea(id: 'bk-notes', classes: 'vf-textarea', onInput: (v) => _notes = v, [Component.text(_notes)]),
          ]),
          button(classes: 'vf-btn vf-btn--primary', type: ButtonType.button, disabled: _submitting, onClick: _submit, [
            Component.text(_submitting ? 'Submitting Request...' : 'Submit Booking Request'),
          ]),
        ]),
      ]),
    ]);
  }
}
