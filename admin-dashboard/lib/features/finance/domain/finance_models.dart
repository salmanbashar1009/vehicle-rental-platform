import 'package:equatable/equatable.dart';

class PeriodFinanceModel extends Equatable {
  const PeriodFinanceModel({
    required this.currency,
    required this.recognizedRevenueMinor,
    required this.cashCollectedMinor,
    required this.pendingCollectionsMinor,
    required this.refundedMinor,
    required this.approvedExpensesMinor,
    required this.netCashFlowMinor,
  });

  factory PeriodFinanceModel.fromJson(Map<String, dynamic> j) => PeriodFinanceModel(
    currency: (j['currency'] ?? 'USD').toString(),
    recognizedRevenueMinor: (j['recognized_revenue_minor'] as num?)?.toInt() ?? 0,
    cashCollectedMinor: (j['cash_collected_minor'] as num?)?.toInt() ?? 0,
    pendingCollectionsMinor: (j['pending_collections_minor'] as num?)?.toInt() ?? 0,
    refundedMinor: (j['refunded_minor'] as num?)?.toInt() ?? 0,
    approvedExpensesMinor: (j['approved_expenses_minor'] as num?)?.toInt() ?? 0,
    netCashFlowMinor: (j['net_cash_flow_minor'] as num?)?.toInt() ?? 0,
  );

  final String currency;
  final int recognizedRevenueMinor;
  final int cashCollectedMinor;
  final int pendingCollectionsMinor;
  final int refundedMinor;
  final int approvedExpensesMinor;
  final int netCashFlowMinor;

  @override
  List<Object?> get props => [
    currency,
    recognizedRevenueMinor,
    cashCollectedMinor,
    refundedMinor,
    approvedExpensesMinor,
    netCashFlowMinor,
  ];
}

class ExpenseRecord extends Equatable {
  const ExpenseRecord({
    required this.id,
    required this.category,
    required this.amountMinor,
    required this.currency,
    required this.description,
    required this.status,
    this.bookingId,
    this.reviewNotes,
  });

  factory ExpenseRecord.fromJson(Map<String, dynamic> j) => ExpenseRecord(
    id: j['id'].toString(),
    bookingId: j['booking_id']?.toString(),
    category: j['category'].toString(),
    amountMinor: (j['amount_minor'] as num).toInt(),
    currency: (j['currency'] ?? 'USD').toString(),
    description: j['description'].toString(),
    status: j['status'].toString(),
    reviewNotes: j['review_notes']?.toString(),
  );

  final String id;
  final String? bookingId;
  final String category;
  final int amountMinor;
  final String currency;
  final String description;
  final String status;
  final String? reviewNotes;

  @override
  List<Object?> get props => [id, category, amountMinor, status];
}

class BookingFinanceLedger extends Equatable {
  const BookingFinanceLedger({
    required this.bookingId,
    required this.bookingReference,
    required this.currency,
    required this.agreedMinor,
    required this.extraMinor,
    required this.discountMinor,
    required this.paidMinor,
    required this.refundedMinor,
    required this.outstandingMinor,
  });

  factory BookingFinanceLedger.fromJson(Map<String, dynamic> j) => BookingFinanceLedger(
    bookingId: j['booking_id'].toString(),
    bookingReference: j['booking_reference'].toString(),
    currency: (j['currency'] ?? 'USD').toString(),
    agreedMinor: (j['agreed_minor'] as num?)?.toInt() ?? 0,
    extraMinor: (j['extra_charges_minor'] as num?)?.toInt() ?? 0,
    discountMinor: (j['discount_minor'] as num?)?.toInt() ?? 0,
    paidMinor: (j['paid_minor'] as num?)?.toInt() ?? 0,
    refundedMinor: (j['refunded_minor'] as num?)?.toInt() ?? 0,
    outstandingMinor: (j['outstanding_minor'] as num?)?.toInt() ?? 0,
  );

  final String bookingId;
  final String bookingReference;
  final String currency;
  final int agreedMinor;
  final int extraMinor;
  final int discountMinor;
  final int paidMinor;
  final int refundedMinor;
  final int outstandingMinor;

  @override
  List<Object?> get props => [bookingId, agreedMinor, paidMinor, refundedMinor, outstandingMinor];
}
