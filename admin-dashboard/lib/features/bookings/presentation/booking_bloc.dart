import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failures.dart';
import '../domain/booking_entity.dart';

enum ViewStatus { initial, loading, loaded, empty, failure }

sealed class BookingEvent extends Equatable {
  const BookingEvent();
  @override
  List<Object?> get props => [];
}

final class BookingsFetchRequested extends BookingEvent {
  const BookingsFetchRequested({this.statusFilter, this.search});
  final String? statusFilter;
  final String? search;
  @override
  List<Object?> get props => [statusFilter, search];
}

final class BookingConfirmRequested extends BookingEvent {
  const BookingConfirmRequested({required this.bookingId, this.reason});
  final String bookingId;
  final String? reason;
  @override
  List<Object?> get props => [bookingId, reason];
}

final class BookingCancelRequested extends BookingEvent {
  const BookingCancelRequested({required this.bookingId, required this.reason});
  final String bookingId;
  final String reason;
  @override
  List<Object?> get props => [bookingId, reason];
}

final class BookingQuoteSubmitted extends BookingEvent {
  const BookingQuoteSubmitted({
    required this.bookingId,
    required this.label,
    required this.amountMinor,
    required this.depositMinor,
    required this.currency,
  });
  final String bookingId;
  final String label;
  final int amountMinor;
  final int depositMinor;
  final String currency;
  @override
  List<Object?> get props => [bookingId, label, amountMinor, depositMinor, currency];
}

class BookingState extends Equatable {
  const BookingState({
    this.viewStatus = ViewStatus.initial,
    this.items = const [],
    this.statusFilter,
    this.search = '',
    this.actionFailure,
    this.loadFailure,
    this.busy = false,
  });

  final ViewStatus viewStatus;
  final List<AdminBookingEntity> items;
  final String? statusFilter;
  final String search;
  final Failure? actionFailure;
  final Failure? loadFailure;
  final bool busy;

  BookingState copyWith({
    ViewStatus? viewStatus,
    List<AdminBookingEntity>? items,
    String? statusFilter,
    String? search,
    Failure? actionFailure,
    bool clearActionFailure = false,
    Failure? loadFailure,
    bool? busy,
  }) => BookingState(
    viewStatus: viewStatus ?? this.viewStatus,
    items: items ?? this.items,
    statusFilter: statusFilter ?? this.statusFilter,
    search: search ?? this.search,
    actionFailure: clearActionFailure ? null : (actionFailure ?? this.actionFailure),
    loadFailure: loadFailure ?? this.loadFailure,
    busy: busy ?? this.busy,
  );

  @override
  List<Object?> get props => [viewStatus, items, statusFilter, search, actionFailure, loadFailure, busy];
}

/// Manages Admin Booking list, filtering, quotations, confirmations, and cancellations.
class BookingBloc extends Bloc<BookingEvent, BookingState> {
  BookingBloc(this._repo) : super(const BookingState()) {
    on<BookingsFetchRequested>(_onFetch);
    on<BookingConfirmRequested>(_onConfirm);
    on<BookingCancelRequested>(_onCancel);
    on<BookingQuoteSubmitted>(_onQuote);
  }

  final AdminBookingRepository _repo;

  Future<void> _onFetch(BookingsFetchRequested e, Emitter<BookingState> emit) async {
    emit(state.copyWith(
      viewStatus: ViewStatus.loading,
      statusFilter: e.statusFilter,
      search: e.search ?? state.search,
      clearActionFailure: true,
    ));
    final res = await _repo.listBookings(status: e.statusFilter, search: e.search ?? state.search);
    res.when(
      ok: (list) => emit(state.copyWith(
        viewStatus: list.isEmpty ? ViewStatus.empty : ViewStatus.loaded,
        items: list,
      )),
      err: (f) => emit(state.copyWith(viewStatus: ViewStatus.failure, loadFailure: f)),
    );
  }

  Future<void> _onConfirm(BookingConfirmRequested e, Emitter<BookingState> emit) async {
    emit(state.copyWith(busy: true, clearActionFailure: true));
    final res = await _repo.confirmBooking(bookingId: e.bookingId, reason: e.reason);
    await res.when(
      ok: (_) async {
        emit(state.copyWith(busy: false));
        add(BookingsFetchRequested(statusFilter: state.statusFilter, search: state.search));
      },
      err: (f) async => emit(state.copyWith(busy: false, actionFailure: f)),
    );
  }

  Future<void> _onCancel(BookingCancelRequested e, Emitter<BookingState> emit) async {
    emit(state.copyWith(busy: true, clearActionFailure: true));
    final res = await _repo.cancelBooking(bookingId: e.bookingId, reason: e.reason);
    await res.when(
      ok: (_) async {
        emit(state.copyWith(busy: false));
        add(BookingsFetchRequested(statusFilter: state.statusFilter, search: state.search));
      },
      err: (f) async => emit(state.copyWith(busy: false, actionFailure: f)),
    );
  }

  Future<void> _onQuote(BookingQuoteSubmitted e, Emitter<BookingState> emit) async {
    emit(state.copyWith(busy: true, clearActionFailure: true));
    final res = await _repo.sendQuotation(
      bookingId: e.bookingId,
      label: e.label,
      amountMinor: e.amountMinor,
      depositMinor: e.depositMinor,
      currency: e.currency,
      validUntil: DateTime.now().toUtc().add(const Duration(days: 3)),
    );
    await res.when(
      ok: (_) async {
        emit(state.copyWith(busy: false));
        add(BookingsFetchRequested(statusFilter: state.statusFilter, search: state.search));
      },
      err: (f) async => emit(state.copyWith(busy: false, actionFailure: f)),
    );
  }
}
