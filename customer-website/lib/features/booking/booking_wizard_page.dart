import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import '../../components/ui/ui_primitives.dart';
import '../../core/auth/auth_session.dart';
import '../../core/config/app_config.dart';
import '../../core/data/default_catalog.dart';
import '../../core/http/api_client.dart';
import '../../core/http/api_error.dart';
import '../../core/models/booking_models.dart';
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
  late String _serviceSlug = component.initialService ?? 'airport_transfer';
  late final String _idempotencyKey = generateUuidV4();
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

  Future<void> _submit() async {
    if (_pickupAddress.trim().isEmpty || _destinationAddress.trim().isEmpty) {
      setState(() => _error = 'Pickup and destination addresses are required.');
      return;
    }
    final auth = CustomerAuthStore.instance;
    if (!auth.isAuthenticated &&
        (_customerName.trim().isEmpty ||
            (_customerEmail.trim().isEmpty && _customerPhone.trim().isEmpty))) {
      setState(() => _error = 'Please provide your name and email or phone number.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final stops = [
        {'stop_type': 'pickup', 'address': _pickupAddress.trim()},
        for (final wp in _waypoints)
          if (wp.trim().isNotEmpty) {'stop_type': 'waypoint', 'address': wp.trim()},
        {'stop_type': 'destination', 'address': _destinationAddress.trim()},
      ];
      final res = await auth.api.post(
        '/bookings',
        idempotencyKey: _idempotencyKey,
        body: {
          'service_slug': _serviceSlug,
          if (component.initialVehicleId != null) 'preferred_vehicle_id': component.initialVehicleId,
          'pickup_at': '$_pickupAt:00Z',
          'expected_end_at': '$_expectedEndAt:00Z',
          'passenger_count': int.tryParse(_passengers) ?? 1,
          'luggage_count': int.tryParse(_luggage) ?? 0,
          'service_metadata_json': _extraMeta,
          if (_notes.trim().isNotEmpty) 'special_instructions': _notes.trim(),
          'stops': stops,
          if (!auth.isAuthenticated) ...{
            'customer_name': _customerName.trim(),
            if (_customerEmail.trim().isNotEmpty) 'customer_email': _customerEmail.trim(),
            if (_customerPhone.trim().isNotEmpty) 'customer_phone': _customerPhone.trim(),
          },
        },
      ) as Map<String, dynamic>;
      final created = BookingDto.fromJson(res);
      if (mounted) {
        Router.of(context).push('/booking/confirmation/${created.reference}');
      }
    } on ApiError catch (e) {
      setState(() {
        _error = '${e.message}${e.correlationId != null ? ' (Ref: ${e.correlationId})' : ''}';
        _submitting = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Unable to submit booking request. Please try again.';
        _submitting = false;
      });
    }
  }

  @override
  Component build(BuildContext context) {
    final svc = ServiceCatalogReference.findBySlug(_serviceSlug) ??
        ServiceCatalogReference.categories.first;
    final auth = CustomerAuthStore.instance;
    return section(classes: 'vf-section', [
      Document.head(title: 'Request Booking or Quote | ${AppConfig.brandName}'),
      div(classes: 'vf-container', [
        div(classes: 'vf-card', [
          h1([Component.text('Request a Booking or Quotation')]),
          p(classes: 'vf-muted', [
            Component.text('Every request receives a unique reference and availability verification.'),
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
                input(classes: 'vf-input', type: InputType.number, value: _luggage, onInput: (v) => _luggage = v.toString()),
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
            onRemoveWaypoint: (i) => setState(() => _waypoints.removeAt(i)),
            onUpdateWaypoint: (i, v) => _waypoints[i] = v,
          ),
          for (final fieldName in svc.extraFields)
            div(classes: 'vf-field', [
              label(classes: 'vf-label', [Component.text(fieldName.replaceAll('_', ' ').toUpperCase())]),
              input(classes: 'vf-input', value: _extraMeta[fieldName] ?? '', onInput: (v) => _extraMeta[fieldName] = v.toString()),
            ]),
          if (!auth.isAuthenticated)
            div(classes: 'vf-grid-3', [
              div(classes: 'vf-field', [
                label(classes: 'vf-label', [Component.text('Your Name')]),
                input(classes: 'vf-input', value: _customerName, onInput: (v) => _customerName = v.toString()),
              ]),
              div(classes: 'vf-field', [
                label(classes: 'vf-label', [Component.text('Email')]),
                input(classes: 'vf-input', type: InputType.email, value: _customerEmail, onInput: (v) => _customerEmail = v.toString()),
              ]),
              div(classes: 'vf-field', [
                label(classes: 'vf-label', [Component.text('Phone')]),
                input(classes: 'vf-input', value: _customerPhone, onInput: (v) => _customerPhone = v.toString()),
              ]),
            ]),
          div(classes: 'vf-field', [
            label(classes: 'vf-label', [Component.text('Special Requirements & Notes')]),
            textarea(classes: 'vf-textarea', onInput: (v) => _notes = v, [Component.text(_notes)]),
          ]),
          button(classes: 'vf-btn vf-btn--primary', disabled: _submitting, onClick: _submit, [
            Component.text(_submitting ? 'Submitting Request...' : 'Submit Booking Request'),
          ]),
        ]),
      ]),
    ]);
  }
}
