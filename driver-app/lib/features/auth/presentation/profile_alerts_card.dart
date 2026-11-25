import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:velofleet_driver/core/network/dio_client.dart';
import 'package:velofleet_driver/features/assignments/presentation/assignments_bloc.dart';

/// Driver completed-job summary and compliance/maintenance expiry alerts card (`DRV-501`).
class DriverPerformanceAlertsCard extends StatefulWidget {
  const DriverPerformanceAlertsCard({super.key});

  @override
  State<DriverPerformanceAlertsCard> createState() => _DriverPerformanceAlertsCardState();
}

class _DriverPerformanceAlertsCardState extends State<DriverPerformanceAlertsCard> {
  List<Map<String, dynamic>> _alerts = const [];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    try {
      final client = context.read<DriverDioClient>();
      final resp = await client.dio.get<List<dynamic>>('/notifications');
      if (!mounted) return;
      final list = (resp.data ?? const [])
          .cast<Map<String, dynamic>>()
          .where((n) => n['event_type'].toString().contains('expir'))
          .toList();
      setState(() => _alerts = list);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final assignments = context.watch<AssignmentsBloc>().state.assignments;
    final completedCount =
        assignments.where((a) => a.trip?.status == 'service_completed').length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Performance & Compliance Alerts', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('Completed Trips Loaded: $completedCount • Total Assigned: ${assignments.length}'),
            const SizedBox(height: 10),
            if (_alerts.isEmpty)
              const Text('No vehicle maintenance or licence expiry warnings.')
            else
              for (final a in _alerts)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  title: Text(a['title'].toString()),
                  subtitle: Text((a['body'] ?? '').toString()),
                ),
          ],
        ),
      ),
    );
  }
}
