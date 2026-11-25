import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/feedback_views.dart';
import '../../../core/widgets/status_badge.dart';
import 'notifications_cubit.dart';

/// Admin operational inbox combining system alerts, driver declines, and trip incidents.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    context.read<NotificationsCubit>().loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Operations Alerts & Incidents'),
        actions: [
          IconButton(
            onPressed: () => context.read<NotificationsCubit>().loadAll(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, state) {
          if (state.loading && state.notifications.isEmpty && state.incidents.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Notifications (${state.unreadCount} unread)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Expanded(
                      child: state.notifications.isEmpty
                          ? const EmptyStateView(
                              title: 'No Notifications',
                              message: 'Dispatch and assignment alerts appear here.',
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: state.notifications.length,
                              itemBuilder: (context, i) {
                                final n = state.notifications[i];
                                return Card(
                                  child: ListTile(
                                    leading: StatusBadge(status: n.priority),
                                    title: Text(
                                      n.title,
                                      style: TextStyle(
                                        fontWeight: n.isRead ? FontWeight.w400 : FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Text(n.body),
                                    trailing: n.isRead
                                        ? const Icon(Icons.done_all, size: 18)
                                        : TextButton(
                                            onPressed: () =>
                                                context.read<NotificationsCubit>().markRead(n.id),
                                            child: const Text('Mark Read'),
                                          ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Driver Incidents (${state.incidents.length})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Expanded(
                      child: state.incidents.isEmpty
                          ? const EmptyStateView(
                              title: 'No Active Incidents',
                              message: 'Driver breakdown or emergency reports show here.',
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: state.incidents.length,
                              itemBuilder: (context, i) {
                                final inc = state.incidents[i];
                                return Card(
                                  child: ListTile(
                                    leading: StatusBadge(status: inc.severity),
                                    title: Text('${inc.category.toUpperCase()} • ${inc.status}'),
                                    subtitle: Text(inc.description),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
