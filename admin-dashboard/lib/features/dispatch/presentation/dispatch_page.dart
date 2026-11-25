import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/feedback_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../../bookings/domain/booking_entity.dart';
import '../../bookings/presentation/booking_bloc.dart';
import 'dispatch_bloc.dart';

/// Split-pane Dispatch Console for assigning eligible vehicles & drivers.
class DispatchPage extends StatefulWidget {
  const DispatchPage({super.key});

  @override
  State<DispatchPage> createState() => _DispatchPageState();
}

class _DispatchPageState extends State<DispatchPage> {
  AdminBookingEntity? _selectedBooking;
  String? _selectedVehicleId;
  String? _selectedDriverId;

  @override
  void initState() {
    super.initState();
    context.read<BookingBloc>().add(const BookingsFetchRequested(statusFilter: 'confirmed'));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Dispatch & Resource Allocation', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Card(
                    child: BlocBuilder<BookingBloc, BookingState>(
                      builder: (context, bState) {
                        if (bState.viewStatus == ViewStatus.loading) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (bState.items.isEmpty) {
                          return const EmptyStateView(
                            title: 'No confirmed bookings awaiting dispatch',
                            message: 'Confirm a booking request before assigning resources.',
                          );
                        }
                        return ListView.separated(
                          itemCount: bState.items.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (ctx, idx) {
                            final b = bState.items[idx];
                            return ListTile(
                              selected: _selectedBooking?.id == b.id,
                              title: Text(b.reference, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text('${b.pickupAddress} → ${b.destinationAddress}'),
                              trailing: StatusBadge(status: b.status),
                              onTap: () {
                                setState(() {
                                  _selectedBooking = b;
                                  _selectedVehicleId = b.preferredVehicleId;
                                  _selectedDriverId = null;
                                });
                                context.read<DispatchBloc>().add(DispatchResourcesRequested(b.id));
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: BlocBuilder<DispatchBloc, DispatchState>(
                        builder: (context, dState) {
                          if (_selectedBooking == null) {
                            return const Center(child: Text('Select a confirmed booking to view eligible vehicles and drivers.'));
                          }
                          if (dState.viewStatus == ViewStatus.loading) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Assign Resources — ${_selectedBooking!.reference}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                              if (dState.failure != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(dState.failure!.message, style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w600)),
                                ),
                              if (dState.assignSuccess)
                                const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text('Assignment saved & locked atomically.', style: TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.w600)),
                                ),
                              const SizedBox(height: 12),
                              const Text('Vehicles', style: TextStyle(fontWeight: FontWeight.w700)),
                              Expanded(
                                child: RadioGroup<String>(
                                  groupValue: _selectedVehicleId,
                                  onChanged: (val) => setState(() => _selectedVehicleId = val),
                                  child: ListView(
                                    children: [
                                      for (final v in dState.vehicles)
                                        RadioListTile<String>(
                                          value: v.id,
                                          enabled: v.isEligible,
                                          title: Text('${v.plateNumber} — ${v.name}'),
                                          subtitle: Text(
                                            v.isEligible
                                                ? 'Eligible (${v.seatCapacity} seats)'
                                                : 'Blocked: ${v.conflictReason}',
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const Text('Drivers', style: TextStyle(fontWeight: FontWeight.w700)),
                              Expanded(
                                child: RadioGroup<String>(
                                  groupValue: _selectedDriverId,
                                  onChanged: (val) => setState(() => _selectedDriverId = val),
                                  child: ListView(
                                    children: [
                                      for (final d in dState.drivers)
                                        RadioListTile<String>(
                                          value: d.id,
                                          enabled: d.isEligible,
                                          title: Text(d.fullName),
                                          subtitle: Text(
                                            d.isEligible
                                                ? 'Eligible (${d.licenceNumber})'
                                                : 'Blocked: ${d.conflictReason}',
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              FilledButton(
                                onPressed: (dState.assignBusy || _selectedVehicleId == null || _selectedDriverId == null)
                                    ? null
                                    : () => context.read<DispatchBloc>().add(
                                        DispatchAssignSubmitted(
                                          bookingId: _selectedBooking!.id,
                                          vehicleId: _selectedVehicleId!,
                                          driverId: _selectedDriverId!,
                                        ),
                                      ),
                                child: Text(dState.assignBusy ? 'Assigning...' : 'Confirm Dispatch Assignment'),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
