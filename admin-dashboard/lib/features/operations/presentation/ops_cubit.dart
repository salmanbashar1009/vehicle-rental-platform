import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/dio_client.dart';

class OpsState extends Equatable {
  const OpsState({
    this.maintenance = const [],
    this.corporate = const [],
    this.crmCustomers = const [],
    this.reviews = const [],
    this.opsReport,
    this.lastScanSummary,
    this.loading = false,
    this.error,
  });

  final List<Map<String, dynamic>> maintenance;
  final List<Map<String, dynamic>> corporate;
  final List<Map<String, dynamic>> crmCustomers;
  final List<Map<String, dynamic>> reviews;
  final Map<String, dynamic>? opsReport;
  final String? lastScanSummary;
  final bool loading;
  final String? error;

  @override
  List<Object?> get props => [
    maintenance,
    corporate,
    crmCustomers,
    reviews,
    opsReport,
    lastScanSummary,
    loading,
    error,
  ];
}

class OpsCubit extends Cubit<OpsState> {
  OpsCubit(this._api) : super(const OpsState());

  final ApiClient _api;

  Future<void> loadAll() async {
    emit(OpsState(
      maintenance: state.maintenance,
      corporate: state.corporate,
      crmCustomers: state.crmCustomers,
      reviews: state.reviews,
      opsReport: state.opsReport,
      loading: true,
    ));
    try {
      final maint = await _api.raw.get<List<dynamic>>('/maintenance');
      final corp = await _api.raw.get<List<dynamic>>('/corporate/accounts');
      final crm = await _api.raw.get<List<dynamic>>('/crm/customers');
      final rep = await _api.raw.get<Map<String, dynamic>>('/reports/operations');
      final revs = await _api.raw.get<List<dynamic>>('/reviews');
      emit(
        OpsState(
          maintenance: (maint.data ?? const []).cast<Map<String, dynamic>>(),
          corporate: (corp.data ?? const []).cast<Map<String, dynamic>>(),
          crmCustomers: (crm.data ?? const []).cast<Map<String, dynamic>>(),
          opsReport: rep.data,
          reviews: (revs.data ?? const []).cast<Map<String, dynamic>>(),
        ),
      );
    } catch (e) {
      emit(OpsState(
        maintenance: state.maintenance,
        corporate: state.corporate,
        crmCustomers: state.crmCustomers,
        reviews: state.reviews,
        opsReport: state.opsReport,
        error: e.toString(),
      ));
    }
  }

  Future<void> runExpiryScan() async {
    final res = await _api.raw.post<Map<String, dynamic>>('/maintenance/expiry-scan');
    final d = res.data ?? const {};
    emit(
      OpsState(
        maintenance: state.maintenance,
        corporate: state.corporate,
        crmCustomers: state.crmCustomers,
        reviews: state.reviews,
        opsReport: state.opsReport,
        lastScanSummary:
            'Doc alerts: ${d['doc_alerts_created'] ?? 0}, Licence alerts: ${d['licence_alerts_created'] ?? 0}',
      ),
    );
  }

  Future<void> moderateReview(String reviewId, String status) async {
    await _api.raw.patch<void>(
      '/reviews/$reviewId/moderate',
      data: {'moderation_status': status},
    );
    await loadAll();
  }
}
