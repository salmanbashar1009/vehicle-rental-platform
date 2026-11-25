import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failures.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/widgets/feedback_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../../bookings/presentation/booking_bloc.dart';

class StaffAccountItem {
  const StaffAccountItem({
    required this.id,
    required this.fullName,
    required this.roles,
    required this.isActive,
    this.email,
  });

  final String id;
  final String fullName;
  final String? email;
  final List<String> roles;
  final bool isActive;
}

/// Manages staff user accounts & role assignments (Owner only).
class UsersCubit extends Cubit<({ViewStatus status, List<StaffAccountItem> items, Failure? failure})> {
  UsersCubit(this._api) : super((status: ViewStatus.initial, items: const [], failure: null));
  final ApiClient _api;

  Future<void> load() async {
    emit((status: ViewStatus.loading, items: state.items, failure: null));
    try {
      final res = await _api.raw.get<Map<String, dynamic>>('/users');
      final items = (res.data!['items'] as List<dynamic>? ?? const []).map((raw) {
        final j = raw as Map<String, dynamic>;
        final roles = (j['roles'] as List<dynamic>? ?? const [])
            .map((r) => (r as Map<String, dynamic>)['slug'] as String)
            .toList();
        return StaffAccountItem(
          id: j['id'] as String,
          fullName: j['full_name'] as String,
          email: j['email'] as String?,
          roles: roles,
          isActive: j['is_active'] as bool,
        );
      }).toList();
      emit((status: items.isEmpty ? ViewStatus.empty : ViewStatus.loaded, items: items, failure: null));
    } catch (e) {
      emit((status: ViewStatus.failure, items: const [], failure: ApiClient.mapDioError(e)));
    }
  }
}

/// Owner-only Users & RBAC management page.
class UsersRolesPage extends StatefulWidget {
  const UsersRolesPage({super.key});

  @override
  State<UsersRolesPage> createState() => _UsersRolesPageState();
}

class _UsersRolesPageState extends State<UsersRolesPage> {
  @override
  void initState() {
    super.initState();
    context.read<UsersCubit>().load();
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
              const Text('Users & Role Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton(onPressed: () => context.read<UsersCubit>().load(), icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BlocBuilder<UsersCubit, ({ViewStatus status, List<StaffAccountItem> items, Failure? failure})>(
              builder: (context, state) {
                if (state.status == ViewStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.status == ViewStatus.failure) {
                  return ErrorStateView(
                    message: state.failure?.message ?? 'Failed to load staff users.',
                    onRetry: () => context.read<UsersCubit>().load(),
                  );
                }
                if (state.status == ViewStatus.empty) {
                  return const EmptyStateView(
                    title: 'No staff users found',
                    message: 'Create staff accounts with least-privilege roles.',
                  );
                }
                return Card(
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Email')),
                        DataColumn(label: Text('Roles')),
                        DataColumn(label: Text('Account')),
                      ],
                      rows: [
                        for (final u in state.items)
                          DataRow(
                            cells: [
                              DataCell(Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.w700))),
                              DataCell(Text(u.email ?? '—')),
                              DataCell(Text(u.roles.join(', '))),
                              DataCell(StatusBadge(status: u.isActive ? 'available' : 'out_of_service')),
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
