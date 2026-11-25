import 'package:flutter/material.dart';

import 'package:velofleet_driver/core/theme/brand_theme.dart';

/// Minimum 54dp full-width primary button designed for stationary gloved/thumb ergonomics.
class LargeTouchButton extends StatelessWidget {
  const LargeTouchButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.backgroundColor,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? backgroundColor;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        style: backgroundColor != null
            ? FilledButton.styleFrom(backgroundColor: backgroundColor)
            : null,
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon ?? Icons.check_circle_outline),
        label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// High-contrast GPS privacy status pill (`GPS Live`, `Buffering`, `GPS Off`).
class TrackingPill extends StatelessWidget {
  const TrackingPill({
    super.key,
    required this.isActive,
    required this.bufferedCount,
    this.healthWarning,
  });

  final bool isActive;
  final int bufferedCount;
  final String? healthWarning;

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).extension<BrandThemeExtension>();
    late Color color;
    late String text;
    if (healthWarning != null && isActive) {
      color = brand?.warning ?? Colors.amber;
      text = healthWarning!;
    } else if (!isActive) {
      color = Colors.blueGrey;
      text = 'GPS Off';
    } else if (bufferedCount > 0) {
      color = brand?.warning ?? Colors.orange;
      text = 'Buffering ($bufferedCount)';
    } else {
      color = brand?.success ?? Colors.green;
      text = 'GPS Live';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(32),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isActive ? Icons.gps_fixed : Icons.gps_off, size: 15, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}

/// Safety gate bottom sheet preventing accidental one-tap irreversible milestone changes.
class ConfirmMilestoneSheet extends StatelessWidget {
  const ConfirmMilestoneSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
  });

  final String title;
  final String subtitle;
  final String confirmLabel;

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String confirmLabel,
  }) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (_) => ConfirmMilestoneSheet(
        title: title,
        subtitle: subtitle,
        confirmLabel: confirmLabel,
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(subtitle),
            const SizedBox(height: 20),
            LargeTouchButton(
              label: confirmLabel,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
