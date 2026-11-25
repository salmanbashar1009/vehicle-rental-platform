/// Customer financial DTOs for itemized quotations, payment ledger, and PDF invoices.
class QuotationLineItemDto {
  const QuotationLineItemDto({
    required this.label,
    required this.quantity,
    required this.unitAmountMinor,
    required this.lineTotalMinor,
  });

  factory QuotationLineItemDto.fromJson(Map<String, dynamic> j) => QuotationLineItemDto(
    label: (j['label'] ?? '').toString(),
    quantity: (j['quantity'] as num?)?.toInt() ?? 1,
    unitAmountMinor: (j['unit_amount_minor'] as num?)?.toInt() ?? 0,
    lineTotalMinor: (j['line_total_minor'] as num?)?.toInt() ?? 0,
  );

  final String label;
  final int quantity;
  final int unitAmountMinor;
  final int lineTotalMinor;
}

class QuotationDetailDto {
  const QuotationDetailDto({
    required this.id,
    required this.bookingId,
    required this.version,
    required this.items,
    required this.subtotalMinor,
    required this.discountMinor,
    required this.taxMinor,
    required this.totalMinor,
    required this.depositMinor,
    required this.currency,
    required this.validUntil,
    required this.status,
    this.terms,
  });

  factory QuotationDetailDto.fromJson(Map<String, dynamic> j) {
    final itemsJson = (j['items_json'] as List<dynamic>?) ?? const [];
    return QuotationDetailDto(
      id: j['id'].toString(),
      bookingId: j['booking_id'].toString(),
      version: (j['version'] as num?)?.toInt() ?? 1,
      items: itemsJson.map((e) => QuotationLineItemDto.fromJson(e as Map<String, dynamic>)).toList(),
      subtotalMinor: (j['subtotal_minor'] as num?)?.toInt() ?? 0,
      discountMinor: (j['discount_minor'] as num?)?.toInt() ?? 0,
      taxMinor: (j['tax_minor'] as num?)?.toInt() ?? 0,
      totalMinor: (j['total_minor'] as num?)?.toInt() ?? 0,
      depositMinor: (j['deposit_minor'] as num?)?.toInt() ?? 0,
      currency: (j['currency'] ?? 'USD').toString(),
      validUntil: j['valid_until'].toString(),
      status: j['status'].toString(),
      terms: j['terms']?.toString(),
    );
  }

  final String id;
  final String bookingId;
  final int version;
  final List<QuotationLineItemDto> items;
  final int subtotalMinor;
  final int discountMinor;
  final int taxMinor;
  final int totalMinor;
  final int depositMinor;
  final String currency;
  final String validUntil;
  final String status;
  final String? terms;
}

class CustomerFinanceSummaryDto {
  const CustomerFinanceSummaryDto({
    required this.bookingId,
    required this.bookingReference,
    required this.currency,
    required this.agreedMinor,
    required this.extraMinor,
    required this.discountMinor,
    required this.paidMinor,
    required this.pendingMinor,
    required this.outstandingMinor,
  });

  factory CustomerFinanceSummaryDto.fromJson(Map<String, dynamic> j) => CustomerFinanceSummaryDto(
    bookingId: j['booking_id'].toString(),
    bookingReference: j['booking_reference'].toString(),
    currency: (j['currency'] ?? 'USD').toString(),
    agreedMinor: (j['agreed_minor'] as num?)?.toInt() ?? 0,
    extraMinor: (j['extra_charges_minor'] as num?)?.toInt() ?? 0,
    discountMinor: (j['discount_minor'] as num?)?.toInt() ?? 0,
    paidMinor: (j['paid_minor'] as num?)?.toInt() ?? 0,
    pendingMinor: (j['pending_minor'] as num?)?.toInt() ?? 0,
    outstandingMinor: (j['outstanding_minor'] as num?)?.toInt() ?? 0,
  );

  final String bookingId;
  final String bookingReference;
  final String currency;
  final int agreedMinor;
  final int extraMinor;
  final int discountMinor;
  final int paidMinor;
  final int pendingMinor;
  final int outstandingMinor;
}

class CustomerInvoiceDto {
  const CustomerInvoiceDto({
    required this.id,
    required this.invoiceNumber,
    required this.totalMinor,
    required this.currency,
    required this.status,
    required this.issuedAt,
  });

  factory CustomerInvoiceDto.fromJson(Map<String, dynamic> j) => CustomerInvoiceDto(
    id: j['id'].toString(),
    invoiceNumber: j['invoice_number'].toString(),
    totalMinor: (j['total_minor'] as num?)?.toInt() ?? 0,
    currency: (j['currency'] ?? 'USD').toString(),
    status: j['status'].toString(),
    issuedAt: j['issued_at'].toString(),
  );

  final String id;
  final String invoiceNumber;
  final int totalMinor;
  final String currency;
  final String status;
  final String issuedAt;
}

String formatMinorAmount(int minor, String currency) {
  final sign = minor < 0 ? '-' : '';
  final absVal = minor.abs();
  return '$sign$currency ${absVal ~/ 100}.${(absVal % 100).toString().padLeft(2, '0')}';
}
