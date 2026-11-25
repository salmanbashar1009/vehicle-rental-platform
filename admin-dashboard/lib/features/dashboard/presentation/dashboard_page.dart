import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/brand_theme.dart';
import '../../../core/widgets/feedback_views.dart';
import '../../../core/widgets/fleet_map_view.dart';
import '../../bookings/presentation/booking_bloc.dart';
import '../../drivers/presentation/drivers_page.dart';
import '../../fleet/presentation/fleet_bloc.dart';

/// Enterprise Operational Dashboard Overview combining KPIs, alerts, and OSM Fleet Map.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    context.read<FleetBloc>().add(const FleetFetchRequested());
    context.read<BookingBloc>().add(const BookingsFetchRequested());
    context.read<DriverCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<BrandTokens>() ?? BrandTokens.light;
    final vehicles = context.watch<FleetBloc>().state.items;
    final bookings = context.watch<BookingBloc>().state.items;
    final drivers = context.watch<DriverCubit>().state.items;

    final availableVehicles = vehicles.where((v) => v.status == 'available').length;
    final maintenanceVehicles = vehicles.where((v) => v.status == 'maintenance').length;
    final pendingBookings = bookings.where((b) => b.status == 'requested').length;
    final availableDrivers = drivers.where((d) => d.availabilityStatus == 'available').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Operations Control Center', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              SizedBox(width: 260, child: KpiCard(label: 'Total Fleet', value: '${vehicles.length}', icon: Icons.directions_car)),
              SizedBox(width: 260, child: KpiCard(label: 'Available Vehicles', value: '$availableVehicles', icon: Icons.check_circle_outline, accentColor: t.successFg)),
              SizedBox(width: 260, child: KpiCard(label: 'In Maintenance', value: '$maintenanceVehicles', icon: Icons.build_outlined, accentColor: t.warningFg)),
              SizedBox(width: 260, child: KpiCard(label: 'Available Drivers', value: '$availableDrivers', icon: Icons.badge_outlined, accentColor: t.secondary600)),
              SizedBox(width: 260, child: KpiCard(label: 'Pending Requests', value: '$pendingBookings', icon: Icons.pending_actions_outlined, accentColor: t.accent500)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 360,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Fleet Operations Map (OSM / flutter_map)', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    const Expanded(child: FleetMapView()),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
