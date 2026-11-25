import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import 'package:velofleet_driver/core/widgets/driver_widgets.dart';
import 'package:velofleet_driver/features/auth/presentation/auth_bloc.dart';
import 'package:velofleet_driver/features/auth/presentation/profile_alerts_card.dart';

/// Prominent OS permission disclosure & driver profile/licence overview screen.
class DriverProfileAndPermissionsPage extends StatelessWidget {
  const DriverProfileAndPermissionsPage({
    super.key,
    required this.darkMode,
    required this.onToggleDarkMode,
  });

  final bool darkMode;
  final ValueChanged<bool> onToggleDarkMode;

  Future<void> _requestLocationPermission(BuildContext context) async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Location permission status: ${perm.name}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<DriverAuthBloc>().state;
    final session = authState is DriverAuthenticated ? authState.session : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session?.fullName ?? 'Driver', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(session?.email ?? ''),
                if (session?.phone != null) Text(session!.phone!),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const DriverPerformanceAlertsCard(),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trip Privacy & Permissions', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                const Text(
                  'VeloFleet collects GPS coordinates ONLY between "En Route to Pickup" '
                  'and "Service Completed". Off-duty tracking never occurs.',
                ),
                const SizedBox(height: 12),
                LargeTouchButton(
                  label: 'Verify Location Permission',
                  icon: Icons.location_on_outlined,
                  onPressed: () => _requestLocationPermission(context),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Night-Driving Dark Mode'),
          subtitle: const Text('Reduces cab glare during night shifts'),
          value: darkMode,
          onChanged: onToggleDarkMode,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          onPressed: () => context.read<DriverAuthBloc>().add(const DriverLogoutRequested()),
          icon: const Icon(Icons.logout),
          label: const Text('Sign Out'),
        ),
      ],
    );
  }
}
