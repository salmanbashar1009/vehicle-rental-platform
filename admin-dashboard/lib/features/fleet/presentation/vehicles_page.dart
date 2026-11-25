import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/feedback_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../../bookings/presentation/booking_bloc.dart';
import 'fleet_bloc.dart';

/// Fleet Management page showing registered vehicles and status controls.
class VehiclesPage extends StatefulWidget {
  const VehiclesPage({super.key});

  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  @override
  void initState() {
    super.initState();
    context.read<FleetBloc>().add(const FleetFetchRequested());
  }

  Future<void> _openCreateDialog() async {
    final plate = TextEditingController();
    final name = TextEditingController();
    final make = TextEditingController();
    final model = TextEditingController();
    final seats = TextEditingController(text: '4');
    String cat = 'sedan';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Register Fleet Vehicle'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: plate, decoration: const InputDecoration(labelText: 'Plate Number')),
              const SizedBox(height: 8),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Display Name')),
              const SizedBox(height: 8),
              TextField(controller: make, decoration: const InputDecoration(labelText: 'Make')),
              const SizedBox(height: 8),
              TextField(controller: model, decoration: const InputDecoration(labelText: 'Model')),
              const SizedBox(height: 8),
              TextField(controller: seats, decoration: const InputDecoration(labelText: 'Passenger Capacity')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save Vehicle')),
        ],
      ),
    );
    if (ok == true && mounted) {
      context.read<FleetBloc>().add(
        FleetCreateRequested(
          plateNumber: plate.text.trim(),
          name: name.text.trim(),
          category: cat,
          make: make.text.trim(),
          model: model.text.trim(),
          year: 2025,
          seatCapacity: int.tryParse(seats.text) ?? 4,
          fuelType: 'hybrid',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('Fleet Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const Spacer(),
              FilledButton.icon(
                onPressed: _openCreateDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Vehicle'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BlocBuilder<FleetBloc, FleetState>(
              builder: (context, state) {
                if (state.viewStatus == ViewStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.viewStatus == ViewStatus.failure) {
                  return ErrorStateView(
                    message: state.loadFailure?.message ?? 'Unable to load fleet.',
                    onRetry: () => context.read<FleetBloc>().add(const FleetFetchRequested()),
                  );
                }
                if (state.viewStatus == ViewStatus.empty) {
                  return EmptyStateView(
                    title: 'No vehicles registered yet',
                    message: 'Register your first vehicle to begin accepting dispatches.',
                    actionLabel: 'Add Vehicle',
                    onAction: _openCreateDialog,
                  );
                }
                return Card(
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Plate')),
                        DataColumn(label: Text('Vehicle')),
                        DataColumn(label: Text('Category')),
                        DataColumn(label: Text('Seats')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Odometer')),
                      ],
                      rows: [
                        for (final v in state.items)
                          DataRow(
                            cells: [
                              DataCell(Text(v.plateNumber, style: const TextStyle(fontWeight: FontWeight.w700))),
                              DataCell(Text('${v.name} (${v.make} ${v.model})')),
                              DataCell(Text(v.category.toUpperCase())),
                              DataCell(Text('${v.seatCapacity}')),
                              DataCell(StatusBadge(status: v.status)),
                              DataCell(Text('${v.odometerKm} km')),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
