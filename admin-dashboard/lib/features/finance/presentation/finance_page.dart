import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/feedback_views.dart';
import '../../../core/widgets/status_badge.dart';
import 'booking_ledger_card.dart';
import 'finance_cubit.dart';

/// Accounting & financial operations desktop workspace (`ADM-401`).
class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  final _bookingIdCtrl = TextEditingController();
  final _payAmtCtrl = TextEditingController(text: '10000');

  @override
  void initState() {
    super.initState();
    context.read<FinanceCubit>().loadDashboard();
  }

  @override
  void dispose() {
    _bookingIdCtrl.dispose();
    _payAmtCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Operations & Reconciliation'),
        actions: [
          IconButton(
            onPressed: () => context.read<FinanceCubit>().loadDashboard(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: BlocBuilder<FinanceCubit, FinanceState>(
        builder: (context, state) {
          final s = state.summary;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(state.error!, style: const TextStyle(color: Colors.red)),
                ),
              if (s != null)
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 220,
                      child: KpiCard(
                        label: 'Recognized Revenue',
                        value: formatMinorCurrency(s.recognizedRevenueMinor, s.currency),
                        icon: Icons.account_balance_outlined,
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: KpiCard(
                        label: 'Cash Collected',
                        value: formatMinorCurrency(s.cashCollectedMinor, s.currency),
                        icon: Icons.payments_outlined,
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: KpiCard(
                        label: 'Approved Expenses',
                        value: formatMinorCurrency(s.approvedExpensesMinor, s.currency),
                        icon: Icons.receipt_long_outlined,
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: KpiCard(
                        label: 'Net Cash Flow',
                        value: formatMinorCurrency(s.netCashFlowMinor, s.currency),
                        icon: Icons.trending_up,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              BookingLedgerCard(
                bookingIdCtrl: _bookingIdCtrl,
                payAmtCtrl: _payAmtCtrl,
                state: state,
              ),
              const SizedBox(height: 20),
              Text(
                'Trip & Fleet Expenses (${state.expenses.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final e in state.expenses)
                Card(
                  child: ListTile(
                    leading: StatusBadge(status: e.status),
                    title: Text(
                      '${e.category.toUpperCase()} • ${formatMinorCurrency(e.amountMinor, e.currency)}',
                    ),
                    subtitle: Text(e.description),
                    trailing: e.status == 'pending'
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () => context.read<FinanceCubit>().decideExpense(
                                  e.id,
                                  'approved',
                                  'Verified',
                                ),
                                child: const Text('Approve'),
                              ),
                              TextButton(
                                onPressed: () => context.read<FinanceCubit>().decideExpense(
                                  e.id,
                                  'rejected',
                                  'Declined',
                                ),
                                child: const Text('Reject'),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
