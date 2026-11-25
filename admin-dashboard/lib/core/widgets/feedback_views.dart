import 'package:flutter/material.dart';

import '../theme/brand_theme.dart';

/// Dashboard KPI statistic card.
class KpiCard extends StatelessWidget {
  const KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    this.accentColor,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<BrandTokens>() ?? BrandTokens.light;
    final accent = accentColor ?? t.primary500;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: TextStyle(color: t.textSecondary, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      color: t.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable empty state widget with clear recovery action.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<BrandTokens>() ?? BrandTokens.light;
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 40, color: t.textSecondary),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(message, style: TextStyle(color: t.textSecondary), textAlign: TextAlign.center),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable error banner/view with retry action.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({required this.message, required this.onRetry, super.key});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<BrandTokens>() ?? BrandTokens.light;
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 40, color: t.errorFg),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center, style: TextStyle(color: t.errorFg)),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirmation dialog capturing an audit reason for sensitive/destructive operations.
Future<String?> showConfirmReasonDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool reasonRequired = true,
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        final invalid = reasonRequired && controller.text.trim().length < 3;
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  onChanged: (_) => setLocal(() {}),
                  decoration: InputDecoration(
                    labelText: reasonRequired ? 'Audit Reason (required)' : 'Audit Reason (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: invalid ? null : () => Navigator.of(ctx).pop(controller.text.trim()),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    ),
  );
}
