import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:velofleet_driver/features/assignments/domain/assignment_models.dart';
import 'package:velofleet_driver/features/assignments/presentation/assignments_bloc.dart';

/// Shows mandatory reason dialog when a driver declines an assigned job.
Future<void> showAssignmentDeclineDialog(BuildContext context, DriverAssignment a) async {
  final ctrl = TextEditingController();
  final reason = await showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('Decline ${a.bookingReference}?'),
      content: TextField(
        controller: ctrl,
        maxLines: 2,
        decoration: const InputDecoration(
          labelText: 'Reason required for dispatcher',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
          child: const Text('Decline Job'),
        ),
      ],
    ),
  );
  if (reason != null && reason.length >= 3 && context.mounted) {
    context.read<AssignmentsBloc>().add(AssignmentDeclined(a.assignmentId, reason));
  }
}

/// Assignment action card for unacknowledged jobs on Driver Home.
class PendingAssignmentCard extends StatelessWidget {
  const PendingAssignmentCard({super.key, required this.assignment});

  final DriverAssignment assignment;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${assignment.bookingReference} • ${assignment.serviceName}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text('${assignment.vehicleName} (${assignment.vehiclePlate})'),
            Text('Passenger: ${assignment.customerName}'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => context.read<AssignmentsBloc>().add(
                      AssignmentAcknowledged(assignment.assignmentId),
                    ),
                    child: const Text('Acknowledge'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => showAssignmentDeclineDialog(context, assignment),
                  child: const Text('Decline'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
