import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import '../../components/ui/ui_primitives.dart';
import '../../core/auth/auth_session.dart';
import '../../core/config/app_config.dart';
import '../../core/http/api_error.dart';

/// Post-service customer review submission form (`WEB-501`).
@client
class ReviewSubmissionPage extends StatefulComponent {
  const ReviewSubmissionPage({required this.bookingId, super.key});

  final String bookingId;

  @override
  State<ReviewSubmissionPage> createState() => _ReviewSubmissionPageState();
}

class _ReviewSubmissionPageState extends State<ReviewSubmissionPage> {
  int _overall = 5;
  int _driver = 5;
  int _vehicle = 5;
  int _service = 5;
  String _comment = '';
  bool _submitted = false;
  String? _error;

  Future<void> _submit() async {
    final auth = CustomerAuthStore.instance;
    if (!auth.isAuthenticated) {
      setState(() => _error = 'Please sign in first.');
      return;
    }
    try {
      await auth.api.post(
        '/reviews',
        body: {
          'booking_id': component.bookingId,
          'overall_rating': _overall,
          'driver_rating': _driver,
          'vehicle_rating': _vehicle,
          'service_rating': _service,
          if (_comment.trim().isNotEmpty) 'comment': _comment.trim(),
        },
      );
      setState(() {
        _submitted = true;
        _error = null;
      });
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    }
  }

  Component _ratingSelect(String labelText, int value, void Function(int) onSelect) {
    return div(classes: 'vf-field', [
      label([Component.text(labelText)]),
      select(
        onChange: (vals) {
          final parsed = int.tryParse(vals.firstOrNull ?? '');
          if (parsed != null) setState(() => onSelect(parsed));
        },
        [
          for (var n = 5; n >= 1; n--)
            option(value: '$n', selected: value == n, [Component.text('$n Stars')]),
        ],
      ),
    ]);
  }

  @override
  Component build(BuildContext context) {
    return section(classes: 'vf-section', [
      Document.head(title: 'Leave a Review | ${AppConfig.brandName}'),
      div(classes: 'vf-container', [
        div(classes: 'vf-card', [
          h1([Component.text('Rate Your Chauffeur Trip')]),
          if (_error != null) ErrorBanner(message: _error!),
          if (_submitted) ...[
            StatusBadge(status: 'completed'),
            p([Component.text('Thank you! Your review has been submitted.')]),
            Link(to: '/dashboard', classes: 'vf-btn vf-btn--primary', children: [Component.text('Back to Portal')]),
          ] else
            div(classes: 'vf-form-grid', [
              _ratingSelect('Overall Experience', _overall, (v) => _overall = v),
              _ratingSelect('Chauffeur Professionalism', _driver, (v) => _driver = v),
              _ratingSelect('Vehicle Condition & Cleanliness', _vehicle, (v) => _vehicle = v),
              _ratingSelect('Punctuality & Service', _service, (v) => _service = v),
              div(classes: 'vf-field', [
                label([Component.text('Feedback Comment (Optional)')]),
                textarea(
                  rows: 3,
                  onInput: (val) => _comment = val,
                  [Component.text(_comment)],
                ),
              ]),
              button(classes: 'vf-btn vf-btn--primary', onClick: _submit, [
                Component.text('Submit Review'),
              ]),
            ]),
        ]),
      ]),
    ]);
  }
}
