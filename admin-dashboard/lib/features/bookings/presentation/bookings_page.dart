import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/feedback_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../domain/booking_entity.dart';
import 'booking_bloc.dart';
import 'quotation_dialog.dart';

/// Booking Management desktop workspace with filters, table, and actions.
class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  final _searchCtrl = TextEditingController();
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    context.read<BookingBloc>().add(const BookingsFetchRequested());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reload() => context.read<BookingBloc>().add(
    BookingsFetchRequested(statusFilter: _statusFilter, search: _searchCtrl.text),
  );

  Future<void> _confirmCancel(AdminBookingEntity b) async {
    final reason = await showConfirmReasonDialog(
      context,
      title: 'Cancel Booking ${b.reference}',
      message: 'Cancelling releases reserved vehicles and records an audit entry.',
      confirmLabel: 'Confirm Cancel',
    );
    if (reason != null && mounted) {
      context.read<BookingBloc>().add(BookingCancelRequested(bookingId: b.id, reason: reason));
    }
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
              const Text(
                'Booking Management',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Search reference...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) => _reload(),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String?>(
                value: _statusFilter,
                hint: const Text('All Statuses'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All Statuses')),
                  DropdownMenuItem(value: 'requested', child: Text('Requested')),
                  DropdownMenuItem(value: 'quoted', child: Text('Quoted')),
                  DropdownMenuItem(value: 'confirmed', child: Text('Confirmed')),
                  DropdownMenuItem(value: 'assigned', child: Text('Assigned')),
                  DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                ],
                onChanged: (v) {
                  setState(() => _statusFilter = v);
                  _reload();
                },
              ),
              const SizedBox(width: 8),
              IconButton(tooltip: 'Refresh', onPressed: _reload, icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BlocBuilder<BookingBloc, BookingState>(
              builder: (context, state) {
                if (state.viewStatus == ViewStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.viewStatus == ViewStatus.failure) {
                  return ErrorStateView(
                    message: state.loadFailure?.message ?? 'Failed to load bookings.',
                    onRetry: _reload,
                  );
                }
                if (state.viewStatus == ViewStatus.empty) {
                  return EmptyStateView(
                    title: 'No bookings match your criteria',
                    message: 'Clear filters or wait for new customer booking requests.',
                    actionLabel: 'Clear Filters',
                    onAction: () {
                      _searchCtrl.clear();
                      setState(() => _statusFilter = null);
                      _reload();
                    },
                  );
                }
                return _buildContent(state);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BookingState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.actionFailure != null)
          MaterialBanner(
            content: Text(state.actionFailure!.message),
            actions: [TextButton(onPressed: _reload, child: const Text('Dismiss'))],
          ),
        Expanded(
          child: Card(
            child: SingleChildScrollView(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Reference')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Route')),
                  DataColumn(label: Text('Pickup (UTC)')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: [
                  for (final b in state.items)
                    DataRow(
                      cells: [
                        DataCell(
                          Text(b.reference, style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        DataCell(StatusBadge(status: b.status)),
                        DataCell(Text('${b.pickupAddress} → ${b.destinationAddress}')),
                        DataCell(Text(b.pickupAt.toUtc().toString().substring(0, 16))),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () => showSendQuotationDialog(context, b),
                                child: const Text('Quote'),
                              ),
                              TextButton(
                                onPressed: () => context.read<BookingBloc>().add(
                                  BookingConfirmRequested(bookingId: b.id),
                                ),
                                child: const Text('Confirm'),
                              ),
                              TextButton(
                                onPressed: () => _confirmCancel(b),
                                child: const Text('Cancel'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
