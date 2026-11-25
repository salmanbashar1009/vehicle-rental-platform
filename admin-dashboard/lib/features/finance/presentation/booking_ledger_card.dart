import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/status_badge.dart';
import 'finance_cubit.dart';

/// Booking financial breakdown, payment recording, and sequential invoice card.
class BookingLedgerCard extends StatelessWidget {
  const BookingLedgerCard({
    super.key,
    required this.bookingIdCtrl,
    required this.payAmtCtrl,
    required this.state,
  });

  final TextEditingController bookingIdCtrl;
  final TextEditingController payAmtCtrl;
  final FinanceState state;

  @override
  Widget build(BuildContext context) {
    final ledger = state.bookingLedger;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Booking Ledger & Invoices', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: bookingIdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Booking UUID',
                      hintText: 'Paste booking UUID to inspect ledger',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: () {
                    final id = bookingIdCtrl.text.trim();
                    if (id.isNotEmpty) context.read<FinanceCubit>().loadBookingFinance(id);
                  },
                  child: const Text('Load Ledger'),
                ),
              ],
            ),
            if (ledger != null) ...[
              const SizedBox(height: 12),
              Text(
                '${ledger.bookingReference} • '
                'Paid: ${formatMinorCurrency(ledger.paidMinor, ledger.currency)} • '
                'Outstanding: ${formatMinorCurrency(ledger.outstandingMinor, ledger.currency)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: payAmtCtrl,
                      decoration: const InputDecoration(labelText: 'Amount (minor)'),
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: () {
                      final amt = int.tryParse(payAmtCtrl.text.trim()) ?? 0;
                      if (amt > 0) {
                        context.read<FinanceCubit>().recordPayment(
                          bookingId: ledger.bookingId,
                          paymentType: 'partial',
                          method: 'bank_transfer',
                          amountMinor: amt,
                          currency: ledger.currency,
                        );
                      }
                    },
                    child: const Text('Record Payment'),
                  ),
                  OutlinedButton(
                    onPressed: () =>
                        context.read<FinanceCubit>().generateInvoice(ledger.bookingId),
                    child: const Text('Issue Invoice'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final inv in state.invoices)
                ListTile(
                  dense: true,
                  title: Text(
                    '${inv['invoice_number']} • '
                    '${formatMinorCurrency((inv['total_minor'] as num).toInt(), inv['currency'].toString())}',
                  ),
                  trailing: StatusBadge(status: inv['status'].toString()),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
