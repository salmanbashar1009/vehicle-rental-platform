import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/dio_client.dart';
import '../domain/finance_models.dart';

class FinanceState extends Equatable {
  const FinanceState({
    this.summary,
    this.expenses = const [],
    this.bookingLedger,
    this.payments = const [],
    this.invoices = const [],
    this.loading = false,
    this.error,
  });

  final PeriodFinanceModel? summary;
  final List<ExpenseRecord> expenses;
  final BookingFinanceLedger? bookingLedger;
  final List<Map<String, dynamic>> payments;
  final List<Map<String, dynamic>> invoices;
  final bool loading;
  final String? error;

  FinanceState copyWith({
    PeriodFinanceModel? summary,
    List<ExpenseRecord>? expenses,
    BookingFinanceLedger? bookingLedger,
    List<Map<String, dynamic>>? payments,
    List<Map<String, dynamic>>? invoices,
    bool? loading,
    String? error,
  }) => FinanceState(
    summary: summary ?? this.summary,
    expenses: expenses ?? this.expenses,
    bookingLedger: bookingLedger ?? this.bookingLedger,
    payments: payments ?? this.payments,
    invoices: invoices ?? this.invoices,
    loading: loading ?? this.loading,
    error: error,
  );

  @override
  List<Object?> get props => [summary, expenses, bookingLedger, payments, invoices, loading, error];
}

class FinanceCubit extends Cubit<FinanceState> {
  FinanceCubit(this._api) : super(const FinanceState());

  final ApiClient _api;
  final _uuid = const Uuid();

  Future<void> loadDashboard() async {
    emit(state.copyWith(loading: true));
    try {
      final sumRes = await _api.raw.get<Map<String, dynamic>>('/finance/summary');
      final expRes = await _api.raw.get<List<dynamic>>('/finance/expenses');
      emit(
        state.copyWith(
          summary: PeriodFinanceModel.fromJson(sumRes.data!),
          expenses: (expRes.data ?? const [])
              .map((e) => ExpenseRecord.fromJson(e as Map<String, dynamic>))
              .toList(),
          loading: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> loadBookingFinance(String bookingId) async {
    try {
      final sumRes = await _api.raw.get<Map<String, dynamic>>(
        '/finance/bookings/$bookingId/summary',
      );
      final payRes = await _api.raw.get<List<dynamic>>('/finance/bookings/$bookingId/payments');
      final invRes = await _api.raw.get<List<dynamic>>('/finance/bookings/$bookingId/invoices');
      emit(
        state.copyWith(
          bookingLedger: BookingFinanceLedger.fromJson(sumRes.data!),
          payments: (payRes.data ?? const []).cast<Map<String, dynamic>>(),
          invoices: (invRes.data ?? const []).cast<Map<String, dynamic>>(),
        ),
      );
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> recordPayment({
    required String bookingId,
    required String paymentType,
    required String method,
    required int amountMinor,
    String currency = 'USD',
  }) async {
    await _api.raw.post<void>(
      '/finance/payments',
      data: {
        'booking_id': bookingId,
        'payment_type': paymentType,
        'method': method,
        'amount_minor': amountMinor,
        'currency': currency,
      },
      options: Options(headers: {'Idempotency-Key': _uuid.v4()}),
    );
    await loadDashboard();
    await loadBookingFinance(bookingId);
  }

  Future<void> issueRefund({
    required String paymentId,
    required String bookingId,
    required int amountMinor,
    required String reason,
  }) async {
    await _api.raw.post<void>(
      '/finance/refunds',
      data: {'payment_id': paymentId, 'amount_minor': amountMinor, 'reason': reason},
      options: Options(headers: {'Idempotency-Key': _uuid.v4()}),
    );
    await loadDashboard();
    await loadBookingFinance(bookingId);
  }

  Future<void> generateInvoice(String bookingId, {int taxMinor = 0}) async {
    await _api.raw.post<void>(
      '/finance/bookings/$bookingId/invoices',
      data: {'tax_minor': taxMinor, 'discount_minor': 0},
    );
    await loadBookingFinance(bookingId);
  }

  Future<void> decideExpense(String expenseId, String decision, String notes) async {
    await _api.raw.post<void>(
      '/finance/expenses/$expenseId/decision',
      data: {'status': decision, 'review_notes': notes},
    );
    await loadDashboard();
  }
}
