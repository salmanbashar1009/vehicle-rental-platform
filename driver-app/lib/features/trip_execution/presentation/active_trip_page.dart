import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:velofleet_driver/core/widgets/driver_widgets.dart';
import 'package:velofleet_driver/core/widgets/stop_overview_map.dart';
import 'package:velofleet_driver/features/assignments/domain/assignment_models.dart';
import 'package:velofleet_driver/features/assignments/presentation/assignments_bloc.dart';
import 'package:velofleet_driver/features/gps_tracking/presentation/gps_tracking_bloc.dart';
import 'package:velofleet_driver/features/trip_execution/presentation/completion_and_incident_dialogs.dart';

/// Active trip execution cockpit with dynamic workflow steps, OSM map, nav, call & completion.
class ActiveTripPage extends StatelessWidget {
  const ActiveTripPage({super.key, required this.assignment});

  final DriverAssignment assignment;

  Future<void> _openExternalNav(StopCoordinate? stop) async {
    if (stop == null) return;
    final query = (stop.lat != null && stop.lng != null)
        ? '${stop.lat},${stop.lng}'
        : Uri.encodeComponent(stop.address);
    final uri = Uri.parse('https://www.openstreetmap.org/directions?to=$query');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _callCustomer(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final trip = assignment.trip;
    final next = assignment.nextMilestone;
    final gpsState = context.watch<GpsTrackingBloc>().state;
    final repo = context.read<DriverOperationsRepository>();
    final primaryStop = assignment.stops.isNotEmpty ? assignment.stops.first : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('${assignment.bookingReference} • ${assignment.serviceName}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TrackingPill(
              isActive: gpsState.isActive,
              bufferedCount: gpsState.bufferedCount,
              healthWarning: gpsState.healthWarning,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StopOverviewMap(stops: assignment.stops),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Passenger: ${assignment.customerName}', style: Theme.of(context).textTheme.titleMedium),
                  Text('Vehicle: ${assignment.vehicleName} (${assignment.vehiclePlate})'),
                  if (assignment.specialInstructions != null) ...[
                    const SizedBox(height: 6),
                    Text('Notes: ${assignment.specialInstructions!}'),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                          onPressed: () => _openExternalNav(primaryStop),
                          icon: const Icon(Icons.navigation_outlined),
                          label: const Text('Navigate'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                          onPressed: () => _callCustomer(assignment.customerPhone),
                          icon: const Icon(Icons.phone_outlined),
                          label: const Text('Call Passenger'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Service Workflow Steps', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final step in assignment.workflowSteps)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            trip?.status == step
                                ? Icons.radio_button_checked
                                : Icons.check_circle_outline,
                            size: 18,
                            color: trip?.status == step ? Theme.of(context).colorScheme.primary : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            step.replaceAll('_', ' ').toUpperCase(),
                            style: TextStyle(
                              fontWeight: trip?.status == step ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (trip != null && next != null)
            LargeTouchButton(
              label: 'Mark: ${next.replaceAll('_', ' ').toUpperCase()}',
              icon: Icons.fast_forward,
              onPressed: () async {
                final ok = await ConfirmMilestoneSheet.show(
                  context,
                  title: 'Confirm Milestone Update',
                  subtitle: 'Advance ${assignment.bookingReference} to ${next.replaceAll('_', ' ')}?',
                  confirmLabel: 'Confirm Update',
                );
                if (!ok || !context.mounted) return;
                context.read<AssignmentsBloc>().add(
                  TripMilestoneAdvanced(
                    tripId: trip.id,
                    assignmentId: assignment.assignmentId,
                    milestone: next,
                  ),
                );
              },
            ),
          if (trip != null && next == null && trip.status != 'service_completed') ...[
            LargeTouchButton(
              label: 'Complete Service & Close GPS',
              icon: Icons.flag_outlined,
              backgroundColor: Colors.green.shade700,
              onPressed: () async {
                final done = await showDialog<bool>(
                  context: context,
                  builder: (_) => TripCompletionDialog(assignment: assignment, repo: repo),
                );
                if (done == true && context.mounted) {
                  context.read<AssignmentsBloc>().add(const AssignmentsRefreshed());
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
          if (trip != null) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => TripIncidentDialog(tripId: trip.id, repo: repo),
              ),
              icon: const Icon(Icons.warning_amber_rounded, color: Colors.red),
              label: const Text('Report Breakdown / Emergency', style: TextStyle(color: Colors.red)),
            ),
          ],
        ],
      ),
    );
  }
}
