import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/dio_client.dart';

class OpsNotification extends Equatable {
  const OpsNotification({
    required this.id,
    required this.eventType,
    required this.title,
    required this.body,
    required this.priority,
    required this.isRead,
    required this.createdAt,
  });

  factory OpsNotification.fromJson(Map<String, dynamic> j) => OpsNotification(
    id: j['id'].toString(),
    eventType: j['event_type'].toString(),
    title: j['title'].toString(),
    body: (j['body'] ?? '').toString(),
    priority: (j['priority'] ?? 'normal').toString(),
    isRead: j['read_at'] != null,
    createdAt: j['created_at'].toString(),
  );

  final String id;
  final String eventType;
  final String title;
  final String body;
  final String priority;
  final bool isRead;
  final String createdAt;

  @override
  List<Object?> get props => [id, isRead, title];
}

class DriverIncidentItem extends Equatable {
  const DriverIncidentItem({
    required this.id,
    required this.tripId,
    required this.category,
    required this.severity,
    required this.description,
    required this.status,
    required this.createdAt,
  });

  factory DriverIncidentItem.fromJson(Map<String, dynamic> j) => DriverIncidentItem(
    id: j['id'].toString(),
    tripId: j['trip_id'].toString(),
    category: j['category'].toString(),
    severity: j['severity'].toString(),
    description: j['description'].toString(),
    status: j['status'].toString(),
    createdAt: j['created_at'].toString(),
  );

  final String id;
  final String tripId;
  final String category;
  final String severity;
  final String description;
  final String status;
  final String createdAt;

  @override
  List<Object?> get props => [id, status, category, severity];
}

class NotificationsState extends Equatable {
  const NotificationsState({
    this.notifications = const [],
    this.incidents = const [],
    this.loading = false,
    this.error,
  });

  final List<OpsNotification> notifications;
  final List<DriverIncidentItem> incidents;
  final bool loading;
  final String? error;

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  @override
  List<Object?> get props => [notifications, incidents, loading, error];
}

class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit(this._api) : super(const NotificationsState());

  final ApiClient _api;

  Future<void> loadAll() async {
    emit(NotificationsState(
      notifications: state.notifications,
      incidents: state.incidents,
      loading: true,
    ));
    try {
      final nRes = await _api.raw.get<List<dynamic>>('/notifications');
      final iRes = await _api.raw.get<List<dynamic>>('/incidents');
      emit(
        NotificationsState(
          notifications: (nRes.data ?? const [])
              .map((e) => OpsNotification.fromJson(e as Map<String, dynamic>))
              .toList(),
          incidents: (iRes.data ?? const [])
              .map((e) => DriverIncidentItem.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
    } catch (e) {
      emit(NotificationsState(
        notifications: state.notifications,
        incidents: state.incidents,
        error: e.toString(),
      ));
    }
  }

  Future<void> markRead(String notificationId) async {
    await _api.raw.post<void>('/notifications/$notificationId/read');
    await loadAll();
  }
}
