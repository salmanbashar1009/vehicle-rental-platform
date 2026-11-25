import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import '../../components/ui/ui_primitives.dart';
import '../../core/auth/auth_session.dart';
import '../../core/config/app_config.dart';
import '../../core/http/api_error.dart';
import '../../core/models/tracking_models.dart';

/// Customer Active Trip Tracking page with live freshness status and inactive-window fallback.
@client
class ActiveTripTrackingPage extends StatefulComponent {
  const ActiveTripTrackingPage({required this.bookingId, super.key});

  final String bookingId;

  @override
  State<ActiveTripTrackingPage> createState() => _ActiveTripTrackingPageState();
}

class _ActiveTripTrackingPageState extends State<ActiveTripTrackingPage> {
  BookingTrackingDto? _tracking;
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _loadTracking();
      _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadTracking());
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTracking() async {
    final auth = CustomerAuthStore.instance;
    if (!auth.isAuthenticated) {
      setState(() => _loading = false);
      return;
    }
    try {
      final json =
          await auth.api.get('/bookings/${component.bookingId}/tracking') as Map<String, dynamic>;
      setState(() {
        _tracking = BookingTrackingDto.fromJson(json);
        _loading = false;
        _error = null;
      });
    } on ApiError catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Component build(BuildContext context) {
    final t = _tracking;
    return section(classes: 'vf-section', [
      Document.head(title: 'Live Trip Tracking | ${AppConfig.brandName}'),
      div(classes: 'vf-container', [
        div(classes: 'vf-card', [
          h1([Component.text('Active Trip Tracking')]),
          if (_loading)
            p([Component.text('Connecting to live trip telemetry...')])
          else if (_error != null)
            ErrorBanner(message: _error!, onRetry: _loadTracking)
          else if (!CustomerAuthStore.instance.isAuthenticated)
            div([
              p([Component.text('Please sign in with the booking owner account to track this trip.')]),
              Link(to: '/login', classes: 'vf-btn vf-btn--primary', children: [Component.text('Sign In')]),
            ])
          else if (t != null) ...[
            div(classes: 'vf-actions-row', [
              StatusBadge(status: t.tripStatus),
              StatusBadge(status: t.freshness),
            ]),
            h2(classes: 'vf-mono', [Component.text(t.bookingReference)]),
            if (!t.trackingActive)
              p([
                Component.text(
                  'Live location sharing activates automatically once your chauffeur begins '
                  'en-route pickup and closes immediately upon trip completion.',
                ),
              ])
            else ...[
              p([
                Component.text(
                  'Chauffeur: ${t.driverDisplayName ?? 'Assigned'} • '
                  '${t.vehicleName ?? ''} (${t.vehiclePlate ?? ''})',
                ),
              ]),
              if (t.lat != null && t.lng != null)
                p(classes: 'vf-mono', [
                  Component.text(
                    'Current GPS: ${t.lat!.toStringAsFixed(5)}, ${t.lng!.toStringAsFixed(5)}',
                  ),
                ]),
            ],
            h3([Component.text('Planned Route Stops')]),
            ol([
              for (final s in t.stops)
                li([Component.text('${s.stopType.toUpperCase()}: ${s.address}')]),
            ]),
          ],
        ]),
      ]),
    ]);
  }
}
