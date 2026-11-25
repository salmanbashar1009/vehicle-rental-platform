import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import '../../components/ui/ui_primitives.dart';
import '../../core/auth/auth_session.dart';
import '../../core/config/app_config.dart';
import '../../core/http/api_error.dart';
import '../../core/models/booking_models.dart';
import '../../core/web/browser_nav.dart';

/// Authenticated Customer Dashboard & Booking History view.
@client
class CustomerPortalPage extends StatefulComponent {
  const CustomerPortalPage({this.showHistoryOnly = false, super.key});
  final bool showHistoryOnly;

  @override
  State<CustomerPortalPage> createState() => _CustomerPortalPageState();
}

class _CustomerPortalPageState extends State<CustomerPortalPage> {
  List<BookingDto> _bookings = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _load();
    } else {
      _loading = false;
    }
  }

  Future<void> _load() async {
    final auth = CustomerAuthStore.instance;
    if (!auth.isAuthenticated) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await auth.api.get('/bookings') as Map<String, dynamic>;
      final items = (res['items'] as List<dynamic>? ?? const [])
          .map((e) => BookingDto.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _bookings = items;
        _loading = false;
      });
    } on ApiError catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Unable to load your bookings.';
        _loading = false;
      });
    }
  }

  @override
  Component build(BuildContext context) {
    final auth = CustomerAuthStore.instance;
    if (!auth.isAuthenticated) {
      return section(classes: 'vf-section', [
        div(classes: 'vf-container vf-card', [
          h1([Component.text('Sign In Required')]),
          p(classes: 'vf-muted', [Component.text('Please sign in to access your customer dashboard and reservations.')]),
          Link(to: '/login', classes: 'vf-btn vf-btn--primary', children: [Component.text('Go to Sign In')]),
        ]),
      ]);
    }
    return section(classes: 'vf-section', [
      Document.head(title: 'Customer Dashboard | ${AppConfig.brandName}'),
      div(classes: 'vf-container', [
        div(
          styles: Styles(display: Display.flex, justifyContent: JustifyContent.spaceBetween, alignItems: AlignItems.center),
          [
            h1([Component.text(component.showHistoryOnly ? 'Booking History' : 'Welcome, ${auth.user?.fullName ?? ''}')]),
            div(styles: Styles(display: Display.flex, gap: Gap.all(10.px)), [
              Link(to: '/book', classes: 'vf-btn vf-btn--primary', children: [Component.text('+ New Booking')]),
              button(
                classes: 'vf-btn vf-btn--outline',
                onClick: () async {
                  await auth.logout();
                  if (mounted) navigateTo(context, '/');
                },
                [Component.text('Sign Out')],
              ),
            ]),
          ],
        ),
        if (_loading)
          div(classes: 'vf-card', [Component.text('Loading your reservations...')])
        else if (_error != null)
          ErrorBanner(message: _error!, onRetry: _load)
        else if (_bookings.isEmpty)
          EmptyState(
            title: 'No bookings yet',
            message: 'Request your first chauffeur-driven vehicle in under two minutes.',
            action: Link(to: '/book', classes: 'vf-btn vf-btn--primary', children: [Component.text('Create Booking Request')]),
          )
        else
          div(classes: 'vf-grid-2', [
            for (final b in _bookings)
              div(classes: 'vf-card', [
                StatusBadge(status: b.status),
                h3(classes: 'vf-mono', [Component.text(b.reference)]),
                p(classes: 'vf-muted', [
                  Component.text('${b.stops.first.address} → ${b.stops.last.address}'),
                ]),
                Link(
                  to: '/dashboard/bookings/${b.id}',
                  classes: 'vf-btn vf-btn--outline',
                  children: [Component.text('View Timeline & Details')],
                ),
              ]),
          ]),
      ]),
    ]);
  }
}
