import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:velofleet_driver/core/network/dio_client.dart';
import 'package:velofleet_driver/features/assignments/presentation/assignments_bloc.dart';

/// Driver trip expenses & approved driver allowance summary view (`DRV-401`).
class DriverExpensesPage extends StatefulWidget {
  const DriverExpensesPage({super.key});

  @override
  State<DriverExpensesPage> createState() => _DriverExpensesPageState();
}

class _DriverExpensesPageState extends State<DriverExpensesPage> {
  List<Map<String, dynamic>> _expenses = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final client = context.read<DriverDioClient>();
      final resp = await client.dio.get<List<dynamic>>('/finance/expenses');
      if (!mounted) return;
      setState(() {
        _expenses = (resp.data ?? const []).cast<Map<String, dynamic>>();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _fmtMinor(int minor, String cur) {
    final abs = minor.abs();
    return '$cur ${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
  }

  Future<void> _openSubmitDialog(BuildContext context) async {
    final assignments = context.read<AssignmentsBloc>().state.assignments;
    if (assignments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No assigned bookings available for trip expenses.')),
      );
      return;
    }
    String bookingId = assignments.first.bookingId;
    String category = 'toll';
    final amtCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Submit Trip Expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: bookingId,
                  decoration: const InputDecoration(labelText: 'Trip Booking'),
                  items: [
                    for (final a in assignments)
                      DropdownMenuItem(value: a.bookingId, child: Text(a.bookingReference)),
                  ],
                  onChanged: (v) => setDlg(() => bookingId = v ?? bookingId),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: 'toll', child: Text('Toll')),
                    DropdownMenuItem(value: 'fuel', child: Text('Fuel')),
                    DropdownMenuItem(value: 'parking', child: Text('Parking')),
                    DropdownMenuItem(value: 'driver_allowance', child: Text('Driver Allowance')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (v) => setDlg(() => category = v ?? 'toll'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amtCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount (minor units, e.g. 1200)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description / Receipt note'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final minor = int.tryParse(amtCtrl.text.trim()) ?? 0;
                if (minor <= 0 || descCtrl.text.trim().length < 3) return;
                await context.read<DriverDioClient>().dio.post<void>(
                  '/finance/expenses',
                  data: {
                    'booking_id': bookingId,
                    'category': category,
                    'amount_minor': minor,
                    'currency': 'USD',
                    'incurred_at': DateTime.now().toUtc().toIso8601String(),
                    'description': descCtrl.text.trim(),
                  },
                );
                if (ctx.mounted) Navigator.of(ctx).pop(true);
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    if (submitted == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final approvedAllowanceMinor = _expenses
        .where((e) => e['category'] == 'driver_allowance' && e['status'] == 'approved')
        .fold<int>(0, (sum, e) => sum + ((e['amount_minor'] as num?)?.toInt() ?? 0));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Approved Driver Allowance', style: TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        _fmtMinor(approvedAllowanceMinor, 'USD'),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _openSubmitDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Log Expense'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red))
        else if (_expenses.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No submitted trip expenses yet.', textAlign: TextAlign.center),
          )
        else
          for (final e in _expenses)
            Card(
              child: ListTile(
                title: Text(
                  '${e['category'].toString().toUpperCase()} • '
                  '${_fmtMinor((e['amount_minor'] as num).toInt(), (e['currency'] ?? 'USD').toString())}',
                ),
                subtitle: Text(
                  '${e['description']}'
                  '${e['review_notes'] != null ? '\nNote: ${e['review_notes']}' : ''}',
                ),
                trailing: Chip(label: Text(e['status'].toString().toUpperCase())),
              ),
            ),
      ],
    );
  }
}
