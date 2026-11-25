import 'package:jaspr_test/jaspr_test.dart';

import 'package:velofleet_customer_web/core/models/finance_models.dart';
import 'package:velofleet_customer_web/features/portal/payment_invoice_page.dart';
import 'package:velofleet_customer_web/features/portal/quotation_detail_page.dart';

void main() {
  group('Customer Finance Models, Quotations & Payments', () {
    test('Finance DTOs parse minor units and format accurately without float math', () {
      expect(formatMinorAmount(15050, 'USD'), 'USD 150.50');
      expect(formatMinorAmount(-200, 'EUR'), '-EUR 2.00');

      final quote = QuotationDetailDto.fromJson({
        'id': 'q-1',
        'booking_id': 'b-1',
        'version': 2,
        'items_json': [
          {'label': 'Sedan Chauffeur', 'quantity': 2, 'unit_amount_minor': 10000, 'line_total_minor': 20000},
        ],
        'subtotal_minor': 20000,
        'discount_minor': 1000,
        'tax_minor': 500,
        'total_minor': 19500,
        'deposit_minor': 5000,
        'currency': 'USD',
        'valid_until': '2026-12-25T10:00:00Z',
        'status': 'sent',
      });
      expect(quote.totalMinor, 19500);
      expect(quote.items.first.label, 'Sedan Chauffeur');

      final sum = CustomerFinanceSummaryDto.fromJson({
        'booking_id': 'b-1',
        'booking_reference': 'VF-900',
        'currency': 'USD',
        'agreed_minor': 20000,
        'extra_charges_minor': 1500,
        'discount_minor': 0,
        'paid_minor': 5000,
        'pending_minor': 0,
        'outstanding_minor': 16500,
      });
      expect(sum.outstandingMinor, 16500);
    });

    testComponents('QuotationDetailPage and PaymentAndInvoicePage render cleanly', (tester) async {
      tester.pumpComponent(const QuotationDetailPage(quotationId: 'q-1'));
      expect(find.text('Quotation Breakdown'), findsOneComponent);

      tester.pumpComponent(const PaymentAndInvoicePage(bookingId: 'b-1'));
      expect(find.text('Payment & Invoices'), findsOneComponent);
    });
  });
}
