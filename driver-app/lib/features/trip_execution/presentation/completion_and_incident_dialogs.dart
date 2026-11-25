import 'package:flutter/material.dart';

import 'package:velofleet_driver/features/assignments/domain/assignment_models.dart';

/// Modal dialogs for trip completion details and urgent incident reporting.
class TripCompletionDialog extends StatefulWidget {
  const TripCompletionDialog({
    super.key,
    required this.assignment,
    required this.repo,
  });

  final DriverAssignment assignment;
  final DriverOperationsRepository repo;

  @override
  State<TripCompletionDialog> createState() => _TripCompletionDialogState();
}

class _TripCompletionDialogState extends State<TripCompletionDialog> {
  final _odoCtrl = TextEditingController();
  final _waitCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _odoCtrl.dispose();
    _waitCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final odo = int.tryParse(_odoCtrl.text.trim());
    if (odo == null || odo <= 0) {
      setState(() => _error = 'Enter valid ending odometer reading.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.repo.completeTrip(
        tripId: widget.assignment.trip!.id,
        endOdometer: odo,
        waitingMinutes: int.tryParse(_waitCtrl.text.trim()) ?? 0,
        notes: _notesCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Complete ${widget.assignment.bookingReference}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            TextField(
              controller: _odoCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Final Odometer (km)*'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _waitCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Waiting Time (minutes)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Completion / Receipt Notes'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: const Text('Finish Trip'),
        ),
      ],
    );
  }
}

class TripIncidentDialog extends StatefulWidget {
  const TripIncidentDialog({super.key, required this.tripId, required this.repo});

  final String tripId;
  final DriverOperationsRepository repo;

  @override
  State<TripIncidentDialog> createState() => _TripIncidentDialogState();
}

class _TripIncidentDialogState extends State<TripIncidentDialog> {
  String _category = 'breakdown';
  String _severity = 'high';
  final _descCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report Urgent Incident'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: const [
                DropdownMenuItem(value: 'breakdown', child: Text('Vehicle Breakdown')),
                DropdownMenuItem(value: 'accident', child: Text('Accident')),
                DropdownMenuItem(value: 'medical', child: Text('Medical Emergency')),
                DropdownMenuItem(value: 'delay', child: Text('Severe Traffic / Delay')),
                DropdownMenuItem(value: 'dispute', child: Text('Customer Dispute')),
              ],
              onChanged: (v) => setState(() => _category = v ?? 'breakdown'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _severity,
              decoration: const InputDecoration(labelText: 'Severity'),
              items: const [
                DropdownMenuItem(value: 'medium', child: Text('Medium')),
                DropdownMenuItem(value: 'high', child: Text('High')),
                DropdownMenuItem(value: 'critical', child: Text('Critical')),
              ],
              onChanged: (v) => setState(() => _severity = v ?? 'high'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'What happened?'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          onPressed: _submitting
              ? null
              : () async {
                  if (_descCtrl.text.trim().length < 5) return;
                  setState(() => _submitting = true);
                  await widget.repo.reportIncident(
                    tripId: widget.tripId,
                    category: _category,
                    severity: _severity,
                    description: _descCtrl.text.trim(),
                  );
                  if (context.mounted) Navigator.of(context).pop(true);
                },
          child: const Text('Send Alert'),
        ),
      ],
    );
  }
}
