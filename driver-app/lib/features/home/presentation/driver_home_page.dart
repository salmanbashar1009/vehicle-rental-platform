import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:velofleet_driver/core/widgets/driver_widgets.dart';
import 'package:velofleet_driver/features/assignments/domain/assignment_models.dart';
import 'package:velofleet_driver/features/assignments/presentation/assignments_bloc.dart';
import 'package:velofleet_driver/features/auth/presentation/profile_page.dart';
import 'package:velofleet_driver/features/expenses/presentation/driver_expenses_page.dart';
import 'package:velofleet_driver/features/gps_tracking/presentation/gps_tracking_bloc.dart';
import 'package:velofleet_driver/features/home/presentation/assignment_card.dart';
import 'package:velofleet_driver/features/trip_execution/presentation/active_trip_page.dart';

/// 3-tab mobile navigation shell: Home Cockpit, Schedule, Profile & Permissions.
class DriverHomePage extends StatefulWidget {
  const DriverHomePage({
    super.key,
    required this.darkMode,
    required this.onToggleDarkMode,
  });

  final bool darkMode;
  final ValueChanged<bool> onToggleDarkMode;

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    context.read<AssignmentsBloc>().add(const AssignmentsRefreshed());
  }

  @override
  Widget build(BuildContext context) {
    final gpsState = context.watch<GpsTrackingBloc>().state;
    return BlocBuilder<AssignmentsBloc, AssignmentsState>(
      builder: (context, state) {
        final active = state.activeAssignment;
        return Scaffold(
          appBar: AppBar(
            title: const Text('VeloFleet Chauffeur'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: TrackingPill(
                  isActive: gpsState.isActive,
                  bufferedCount: gpsState.bufferedCount,
                  healthWarning: gpsState.healthWarning,
                ),
              ),
              IconButton(
                onPressed: () => context.read<AssignmentsBloc>().add(const AssignmentsRefreshed()),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: switch (_tab) {
            0 => _buildHomeTab(context, state, active),
            1 => _buildScheduleTab(context, state),
            2 => const DriverExpensesPage(),
            _ => DriverProfileAndPermissionsPage(
                darkMode: widget.darkMode,
                onToggleDarkMode: widget.onToggleDarkMode,
              ),
          },
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.event_note_outlined), label: 'Schedule'),
              NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Expenses'),
              NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHomeTab(BuildContext context, AssignmentsState state, DriverAssignment? active) {
    return RefreshIndicator(
      onRefresh: () async => context.read<AssignmentsBloc>().add(const AssignmentsRefreshed()),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(state.error!, style: const TextStyle(color: Colors.red)),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Duty Status', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  DropdownButton<String>(
                    value: state.dutyStatus,
                    items: const [
                      DropdownMenuItem(value: 'available', child: Text('Available')),
                      DropdownMenuItem(value: 'on_break', child: Text('On Break')),
                      DropdownMenuItem(value: 'off_duty', child: Text('Off Duty')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        context.read<AssignmentsBloc>().add(DutyStatusToggled(v));
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (active != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active Assignment • ${active.bookingReference}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text('${active.serviceName} • ${active.customerName}'),
                    Text('Status: ${active.trip?.status.replaceAll('_', ' ')}'),
                    const SizedBox(height: 12),
                    LargeTouchButton(
                      label: 'Open Trip Cockpit',
                      icon: Icons.directions_car,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => ActiveTripPage(assignment: active)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            for (final a in state.assignments) PendingAssignmentCard(assignment: a),
            if (state.assignments.isEmpty && !state.isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No assigned jobs right now.', textAlign: TextAlign.center),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildScheduleTab(BuildContext context, AssignmentsState state) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.assignments.length,
      itemBuilder: (context, i) {
        final a = state.assignments[i];
        return Card(
          child: ListTile(
            title: Text('${a.bookingReference} • ${a.serviceName}'),
            subtitle: Text('${a.pickupAt.toLocal()} • ${a.assignmentStatus}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: a.trip != null
                ? () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => ActiveTripPage(assignment: a)),
                  )
                : null,
          ),
        );
      },
    );
  }
}
