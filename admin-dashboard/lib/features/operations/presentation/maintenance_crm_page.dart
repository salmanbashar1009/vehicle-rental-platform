import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/feedback_views.dart';
import '../../../core/widgets/status_badge.dart';
import 'ops_cubit.dart';

/// Fleet maintenance schedules, expiry scanner, and Corporate/CRM workspace (`ADM-501`).
class MaintenanceCrmPage extends StatefulWidget {
  const MaintenanceCrmPage({super.key});

  @override
  State<MaintenanceCrmPage> createState() => _MaintenanceCrmPageState();
}

class _MaintenanceCrmPageState extends State<MaintenanceCrmPage> {
  @override
  void initState() {
    super.initState();
    context.read<OpsCubit>().loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance & Corporate CRM'),
        actions: [
          FilledButton.tonalIcon(
            onPressed: () => context.read<OpsCubit>().runExpiryScan(),
            icon: const Icon(Icons.notifications_paused_outlined),
            label: const Text('Scan Expiries'),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => context.read<OpsCubit>().loadAll(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: BlocBuilder<OpsCubit, OpsState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (state.lastScanSummary != null)
                Card(
                  color: const Color(0xFFD1FAE5),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Expiry Scan Complete — ${state.lastScanSummary}'),
                  ),
                ),
              Text(
                'Vehicle Maintenance Schedules (${state.maintenance.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (state.maintenance.isEmpty)
                const EmptyStateView(
                  title: 'No Maintenance Scheduled',
                  message: 'Preventive and repair locks appear here.',
                )
              else
                for (final m in state.maintenance)
                  Card(
                    child: ListTile(
                      leading: StatusBadge(status: m['status'].toString()),
                      title: Text('${m['maint_type'].toString().toUpperCase()} — ${m['description']}'),
                      subtitle: Text('Start: ${m['scheduled_start']}'),
                    ),
                  ),
              const SizedBox(height: 20),
              Text(
                'Corporate Accounts (${state.corporate.length}) & CRM Customers (${state.crmCustomers.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final c in state.corporate)
                Card(
                  child: ListTile(
                    title: Text(c['company_name'].toString()),
                    subtitle: Text(
                      'Billing: ${c['billing_cycle']} • Discount: ${c['negotiated_discount_bps']} bps',
                    ),
                    trailing: StatusBadge(status: c['is_active'] == true ? 'available' : 'offline'),
                  ),
                ),
              for (final cust in state.crmCustomers)
                Card(
                  child: ListTile(
                    title: Text('${cust['full_name']} (${cust['customer_type']})'),
                    subtitle: Text('${cust['email'] ?? cust['phone'] ?? ''} • Bookings: ${cust['total_bookings']}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
