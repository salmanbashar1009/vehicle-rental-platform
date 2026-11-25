import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/feedback_views.dart';
import '../../../core/widgets/status_badge.dart';
import 'ops_cubit.dart';

/// Operational KPI analytics and customer review moderation desk (`ADM-501`).
class ReportsAndReviewsPage extends StatefulWidget {
  const ReportsAndReviewsPage({super.key});

  @override
  State<ReportsAndReviewsPage> createState() => _ReportsAndReviewsPageState();
}

class _ReportsAndReviewsPageState extends State<ReportsAndReviewsPage> {
  @override
  void initState() {
    super.initState();
    context.read<OpsCubit>().loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Reviews Moderation'),
        actions: [
          IconButton(
            onPressed: () => context.read<OpsCubit>().loadAll(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: BlocBuilder<OpsCubit, OpsState>(
        builder: (context, state) {
          final rep = state.opsReport;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (rep != null)
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 210,
                      child: KpiCard(
                        label: 'Fleet Utilization',
                        value: '${rep['vehicle_utilization_pct']}%',
                        icon: Icons.directions_car,
                      ),
                    ),
                    SizedBox(
                      width: 210,
                      child: KpiCard(
                        label: 'Cancellation Rate',
                        value: '${rep['cancellation_rate_pct']}%',
                        icon: Icons.cancel_outlined,
                      ),
                    ),
                    SizedBox(
                      width: 210,
                      child: KpiCard(
                        label: 'Repeat Customers',
                        value: '${rep['repeat_customers']}',
                        icon: Icons.repeat,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              Text(
                'Customer Reviews (${state.reviews.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final r in state.reviews)
                Card(
                  child: ListTile(
                    leading: StatusBadge(status: r['moderation_status'].toString()),
                    title: Text('Overall: ${r['overall_rating']}/5 • Driver: ${r['driver_rating']}/5'),
                    subtitle: Text((r['comment'] ?? 'No written comment').toString()),
                    trailing: TextButton(
                      onPressed: () {
                        final next = r['moderation_status'] == 'published' ? 'hidden' : 'published';
                        context.read<OpsCubit>().moderateReview(r['id'].toString(), next);
                      },
                      child: Text(r['moderation_status'] == 'published' ? 'Hide' : 'Publish'),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
