import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import '../../components/ui/ui_primitives.dart';
import '../../core/auth/auth_session.dart';
import '../../core/config/app_config.dart';
import '../../core/http/api_error.dart';
import '../../core/models/finance_models.dart';

/// Customer Quotation Details page with itemized charges, expiry check, and accept/reject.
@client
class QuotationDetailPage extends StatefulComponent {
  const QuotationDetailPage({required this.quotationId, super.key});

  final String quotationId;

  @override
  State<QuotationDetailPage> createState() => _QuotationDetailPageState();
}

class _QuotationDetailPageState extends State<QuotationDetailPage> {
  QuotationDetailDto? _quote;
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
      final json =
          await auth.api.get('/quotations/${component.quotationId}') as Map<String, dynamic>;
      setState(() {
        _quote = QuotationDetailDto.fromJson(json);
        _loading = false;
      });
    } on ApiError catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _respond(bool accept) async {
    try {
      final action = accept ? 'accept' : 'reject';
      await CustomerAuthStore.instance.api.post(
        '/quotations/${component.quotationId}/$action',
      );
      await _load();
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Component build(BuildContext context) {
    final q = _quote;
    return section(classes: 'vf-section', [
      Document.head(title: 'Quotation Details | ${AppConfig.brandName}'),
      div(classes: 'vf-container', [
        div(classes: 'vf-card', [
          h1([Component.text('Quotation Breakdown')]),
          if (_loading)
            p([Component.text('Loading quotation...')])
          else if (_error != null)
            ErrorBanner(message: _error!, onRetry: _load)
          else if (!CustomerAuthStore.instance.isAuthenticated)
            Link(to: '/login', classes: 'vf-btn vf-btn--primary', children: [Component.text('Sign In to View')])
          else if (q != null) ...[
            StatusBadge(status: q.status),
            p([Component.text('Version v${q.version} • Valid Until: ${q.validUntil}')]),
            ul([
              for (final item in q.items)
                li([
                  Component.text(
                    '${item.label} x${item.quantity}: ${formatMinorAmount(item.lineTotalMinor, q.currency)}',
                  ),
                ]),
            ]),
            p(classes: 'vf-mono', [
              Component.text(
                'Total: ${formatMinorAmount(q.totalMinor, q.currency)} • '
                'Deposit Required: ${formatMinorAmount(q.depositMinor, q.currency)}',
              ),
            ]),
            if (q.terms != null) p([Component.text('Terms: ${q.terms}')]),
            if (q.status == 'sent')
              div(classes: 'vf-actions-row', [
                button(classes: 'vf-btn vf-btn--primary', onClick: () => _respond(true), [
                  Component.text('Accept Quotation'),
                ]),
                button(classes: 'vf-btn vf-btn--danger', onClick: () => _respond(false), [
                  Component.text('Reject'),
                ]),
              ]),
          ],
        ]),
      ]),
    ]);
  }
}
