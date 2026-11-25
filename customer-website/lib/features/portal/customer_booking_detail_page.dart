import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import '../../components/ui/ui_primitives.dart';
import '../../core/auth/auth_session.dart';
import '../../core/config/app_config.dart';
import '../../core/http/api_error.dart';
import '../../core/models/booking_models.dart';

/// Customer Booking Detail page with timeline and cancellation request.
@client
class CustomerBookingDetailPage extends StatefulComponent {
  const CustomerBookingDetailPage({required this.bookingId, super.key});
  final String bookingId;

  @override
  State<CustomerBookingDetailPage> createState() => _CustomerBookingDetailPageState();
}

class _CustomerBookingDetailPageState extends State<CustomerBookingDetailPage> {
  BookingDto? _booking;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = CustomerAuthStore.instance;
    if (!auth.isAuthenticated) {
      setState(() => _loading = false);
      return;
    }
    try {
      final json = await auth.api.get('/bookings/${component.bookingId}') as Map<String, dynamic>;
      setState(() {
        _booking = BookingDto.fromJson(json);
        _loading = false;
      });
    } on ApiError catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _cancel() async {
    try {
      await CustomerAuthStore.instance.api.post(
        '/bookings/${component.bookingId}/cancel',
        body: {'reason': 'Cancelled by customer via portal'},
      );
      await _load();
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Component build(BuildContext context) {
    return section(classes: 'vf-section', [
      Document.head(title: 'Booking Details | ${AppConfig.brandName}'),
      div(classes: 'vf-container', [
        if (!CustomerAuthStore.instance.isAuthenticated)
          Link(to: '/login', classes: 'vf-btn vf-btn--primary', children: [Component.text('Sign In to View')])
        else if (_loading)
          div(classes: 'vf-card', [Component.text('Loading booking...')])
        else if (_error != null)
          ErrorBanner(message: _error!, onRetry: _load)
        else if (_booking != null)
          div(classes: 'vf-card', [
            StatusBadge(status: _booking!.status),
            h1(classes: 'vf-mono', [Component.text(_booking!.reference)]),
            h3([Component.text('Stops')]),
            ol([
              for (final s in _booking!.stops)
                li([Component.text('${s.stopType.toUpperCase()}: ${s.address}')]),
            ]),
            h3([Component.text('Status Timeline')]),
            ul([
              for (final t in _booking!.timeline)
                li([Component.text('${t.toStatus.toUpperCase()} — ${t.reason ?? ''}')]),
            ]),
            if (['completed', 'closed'].contains(_booking!.status))
              div(classes: 'vf-actions-row', [
                Link(
                  to: '/dashboard/payments/${_booking!.id}',
                  classes: 'vf-btn vf-btn--secondary',
                  children: [Component.text('Payments & Invoices')],
                ),
                Link(
                  to: '/dashboard/reviews/${_booking!.id}',
                  classes: 'vf-btn vf-btn--primary',
                  children: [Component.text('Leave a Review')],
                ),
              ]),
            if (!['cancelled', 'completed', 'closed', 'rejected'].contains(_booking!.status)) ...[
              div(classes: 'vf-actions-row', [
                Link(
                  to: '/dashboard/track/${_booking!.id}',
                  classes: 'vf-btn vf-btn--primary',
                  children: [Component.text('Track Live Trip')],
                ),
                Link(
                  to: '/dashboard/payments/${_booking!.id}',
                  classes: 'vf-btn vf-btn--secondary',
                  children: [Component.text('Payments & Invoices')],
                ),
                button(classes: 'vf-btn vf-btn--danger', onClick: _cancel, [
                  Component.text('Cancel Booking'),
                ]),
              ]),
            ],
          ]),
      ]),
    ]);
  }
}
