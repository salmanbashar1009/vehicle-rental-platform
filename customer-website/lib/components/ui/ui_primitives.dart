import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Semantic status badge aligned with shared-contracts/design-tokens.md.
class StatusBadge extends StatelessComponent {
  const StatusBadge({required this.status, super.key});

  final String status;

  String get _variantClass => switch (status) {
    'confirmed' || 'completed' || 'closed' || 'available' || 'live' || 'accepted' =>
      'vf-badge--success',
    'requested' || 'under_review' || 'quoted' || 'pending_ack' || 'stale' =>
      'vf-badge--warning',
    'rejected' || 'cancelled' || 'expired' || 'offline' || 'maintenance' || 'out_of_service' =>
      'vf-badge--error',
    _ => 'vf-badge--info',
  };

  @override
  Component build(BuildContext context) {
    final label = status.replaceAll('_', ' ').toUpperCase();
    return span(classes: 'vf-badge $_variantClass', [Component.text(label)]);
  }
}

/// Reusable empty state card with optional action.
class EmptyState extends StatelessComponent {
  const EmptyState({
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  final String title;
  final String message;
  final Component? action;

  @override
  Component build(BuildContext context) {
    return div(classes: 'vf-card', [
      h3([Component.text(title)]),
      p(classes: 'vf-muted', [Component.text(message)]),
      if (action != null) action!,
    ]);
  }
}

/// Reusable error banner with optional retry callback.
class ErrorBanner extends StatelessComponent {
  const ErrorBanner({
    required this.message,
    this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Component build(BuildContext context) {
    return div(
      classes: 'vf-card',
      attributes: {'role': 'alert'},
      styles: Styles(
        backgroundColor: Color('var(--color-error-bg)'),
        border: Border.all(color: Color('var(--color-error-fg)'), width: 1.px),
      ),
      [
        p(
          styles: Styles(color: Color('var(--color-error-fg)'), fontWeight: FontWeight.w600),
          [Component.text(message)],
        ),
        if (onRetry != null)
          button(
            classes: 'vf-btn vf-btn--outline',
            onClick: onRetry,
            [Component.text('Try Again')],
          ),
      ],
    );
  }
}
