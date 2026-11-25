import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failures.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/widgets/feedback_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../../bookings/presentation/booking_bloc.dart';
import '../domain/driver_entity.dart';

/// Dio-backed driver repository.
class DriverRepositoryImpl implements DriverRepository {
  DriverRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<Result<List<DriverEntity>>> listDrivers() async {
    try {
      final res = await _api.raw.get<Map<String, dynamic>>('/drivers');
      final items = (res.data!['items'] as List<dynamic>? ?? const [])
          .map((raw) {
            final j = raw as Map<String, dynamic>;
            return DriverEntity(
              id: j['id'] as String,
              fullName: j['full_name'] as String,
              phone: j['phone'] as String?,
              licenceNumber: j['licence_number'] as String,
              licenceExpiry: DateTime.parse(j['licence_expiry'] as String),
              availabilityStatus: j['availability_status'] as String,
            );
          })
          .toList();
      return Success(items);
    } catch (e) {
      return Err(ApiClient.mapDioError(e));
    }
  }
}

/// Manages Driver directory state.
class DriverCubit extends Cubit<({ViewStatus status, List<DriverEntity> items, Failure? failure})> {
  DriverCubit(this._repo) : super((status: ViewStatus.initial, items: const [], failure: null));
  final DriverRepository _repo;

  Future<void> load() async {
    emit((status: ViewStatus.loading, items: state.items, failure: null));
    final res = await _repo.listDrivers();
    res.when(
      ok: (list) => emit((
        status: list.isEmpty ? ViewStatus.empty : ViewStatus.loaded,
        items: list,
        failure: null,
      )),
      err: (f) => emit((status: ViewStatus.failure, items: const [], failure: f)),
    );
  }
}

/// Drivers Management desktop page.
class DriversPage extends StatefulWidget {
  const DriversPage({super.key});

  @override
  State<DriversPage> createState() => _DriversPageState();
}

class _DriversPageState extends State<DriversPage> {
  @override
  void initState() {
    super.initState();
    context.read<DriverCubit>().load();
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
              const Text('Driver Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton(onPressed: () => context.read<DriverCubit>().load(), icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BlocBuilder<DriverCubit, ({ViewStatus status, List<DriverEntity> items, Failure? failure})>(
              builder: (context, state) {
                if (state.status == ViewStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.status == ViewStatus.failure) {
                  return ErrorStateView(
                    message: state.failure?.message ?? 'Failed to load drivers.',
                    onRetry: () => context.read<DriverCubit>().load(),
                  );
                }
                if (state.status == ViewStatus.empty) {
                  return const EmptyStateView(
                    title: 'No drivers found',
                    message: 'Onboard chauffeurs to assign them to confirmed bookings.',
                  );
                }
                return Card(
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Chauffeur')),
                        DataColumn(label: Text('Phone')),
                        DataColumn(label: Text('Licence #')),
                        DataColumn(label: Text('Expiry')),
                        DataColumn(label: Text('Availability')),
                      ],
                      rows: [
                        for (final d in state.items)
                          DataRow(
                            cells: [
                              DataCell(Text(d.fullName, style: const TextStyle(fontWeight: FontWeight.w700))),
                              DataCell(Text(d.phone ?? '—')),
                              DataCell(Text(d.licenceNumber)),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(d.licenceExpiry.toIso8601String().substring(0, 10)),
                                    if (d.isLicenceExpiringSoon) ...[
                                      const SizedBox(width: 8),
                                      const StatusBadge(status: 'warning'),
                                    ],
                                  ],
                                ),
                              ),
                              DataCell(StatusBadge(status: d.availabilityStatus)),
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
