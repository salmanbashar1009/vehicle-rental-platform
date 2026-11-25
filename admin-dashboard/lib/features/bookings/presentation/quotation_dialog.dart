import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/booking_entity.dart';
import 'booking_bloc.dart';

/// Opens itemized quotation modal for a booking and dispatches BookingQuoteSubmitted.
Future<void> showSendQuotationDialog(BuildContext context, AdminBookingEntity booking) async {
  final labelCtrl = TextEditingController(text: 'Chauffeur Service (${booking.reference})');
  final amountCtrl = TextEditingController(text: '15000');
  final depositCtrl = TextEditingController(text: '5000');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Send Quotation — ${booking.reference}'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(labelText: 'Line Item Label'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountCtrl,
              decoration: const InputDecoration(
                labelText: 'Amount (Minor Units, e.g. 15000 = 150.00)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: depositCtrl,
              decoration: const InputDecoration(labelText: 'Deposit (Minor Units)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send Quote')),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    context.read<BookingBloc>().add(
      BookingQuoteSubmitted(
        bookingId: booking.id,
        label: labelCtrl.text.trim(),
        amountMinor: int.tryParse(amountCtrl.text.trim()) ?? 0,
        depositMinor: int.tryParse(depositCtrl.text.trim()) ?? 0,
        currency: 'USD',
      ),
    );
  }
}
