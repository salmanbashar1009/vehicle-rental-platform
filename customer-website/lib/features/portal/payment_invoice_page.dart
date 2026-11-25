import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import '../../components/ui/ui_primitives.dart';
import '../../core/auth/auth_session.dart';
import '../../core/config/app_config.dart';
import '../../core/http/api_client.dart';
import '../../core/http/api_error.dart';
import '../../core/models/finance_models.dart';

/// Customer Payment & Invoice portal showing balance breakdown, payment trigger, and PDF links.
@client
class PaymentAndInvoicePage extends StatefulComponent {
  const PaymentAndInvoicePage({required this.bookingId, super.key});

  final String bookingId;

  @override
  State<PaymentAndInvoicePage> createState() => _PaymentAndInvoicePageState();
}

class _PaymentAndInvoicePageState extends State<PaymentAndInvoicePage> {
  CustomerFinanceSummaryDto? _summary;
  List<CustomerInvoiceDto> _invoices = const [];
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
    try {
      final sum =
          await auth.api.get('/finance/bookings/${component.bookingId}/summary')
              as Map<String, dynamic>;
      final invs =
          await auth.api.get('/finance/bookings/${component.bookingId}/invoices') as List<dynamic>;
      setState(() {
        _summary = CustomerFinanceSummaryDto.fromJson(sum);
        _invoices = invs.map((e) => CustomerInvoiceDto.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } on ApiError catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _payOutstanding() async {
    final s = _summary;
    if (s == null || s.outstandingMinor <= 0) return;
    try {
      await CustomerAuthStore.instance.api.post(
        '/finance/payments',
        idempotencyKey: generateUuidV4(),
        body: {
          'booking_id': component.bookingId,
          'payment_type': s.paidMinor == 0 ? 'deposit' : 'full',
          'method': 'online_gateway',
          'amount_minor': s.outstandingMinor,
          'currency': s.currency,
        },
      );
      await _load();
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Component build(BuildContext context) {
    final s = _summary;
    return section(classes: 'vf-section', [
      Document.head(title: 'Payment & Invoices | ${AppConfig.brandName}'),
      div(classes: 'vf-container', [
        div(classes: 'vf-card', [
          h1([Component.text('Payment & Invoices')]),
          if (_loading)
            p([Component.text('Loading payment statement...')])
          else if (_error != null)
            ErrorBanner(message: _error!, onRetry: _load)
          else if (!CustomerAuthStore.instance.isAuthenticated)
            Link(to: '/login', classes: 'vf-btn vf-btn--primary', children: [Component.text('Sign In')])
          else if (s != null) ...[
            h2(classes: 'vf-mono', [Component.text(s.bookingReference)]),
            p([Component.text('Agreed Value: ${formatMinorAmount(s.agreedMinor, s.currency)}')]),
            p([Component.text('Paid (Reconciled): ${formatMinorAmount(s.paidMinor, s.currency)}')]),
            p([Component.text('Pending Verification: ${formatMinorAmount(s.pendingMinor, s.currency)}')]),
            p(classes: 'vf-mono', [
              Component.text('Outstanding Balance: ${formatMinorAmount(s.outstandingMinor, s.currency)}'),
            ]),
            if (s.outstandingMinor > 0)
              button(classes: 'vf-btn vf-btn--primary', onClick: _payOutstanding, [
                Component.text('Submit Online Payment'),
              ]),
            h3([Component.text('Issued Invoices')]),
            if (_invoices.isEmpty)
              p([Component.text('No invoices generated yet.')])
            else
              ul([
                for (final inv in _invoices)
                  li([
                    Component.text(
                      '${inv.invoiceNumber} — ${formatMinorAmount(inv.totalMinor, inv.currency)} (${inv.status}) ',
                    ),
                    a(
                      href: '${AppConfig.apiBaseUrl}/finance/invoices/${inv.id}/pdf',
                      target: Target.blank,
                      [Component.text('Download PDF')],
                    ),
                  ]),
              ]),
          ],
        ]),
      ]),
    ]);
  }
}
