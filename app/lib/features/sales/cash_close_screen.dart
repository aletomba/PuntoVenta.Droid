import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../data/sales/sales_repository.dart';
import 'sale_display_formatters.dart';

class CashCloseScreen extends ConsumerStatefulWidget {
  const CashCloseScreen({super.key});

  @override
  ConsumerState<CashCloseScreen> createState() => _CashCloseScreenState();
}

class _CashCloseScreenState extends ConsumerState<CashCloseScreen> {
  late DateTime _selectedDay = _utcDateOnly(DateTime.now().toUtc());

  Future<void> _selectDay() async {
    final nowUtc = DateTime.now().toUtc();
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(
        _selectedDay.year,
        _selectedDay.month,
        _selectedDay.day,
      ),
      firstDate: DateTime(2000),
      lastDate: DateTime(nowUtc.year, nowUtc.month, nowUtc.day),
    );
    if (selected != null && mounted) {
      setState(() => _selectedDay = _utcDateOnly(selected));
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(cashCloseSummaryProvider(_selectedDay));
    return Scaffold(
      appBar: AppBar(title: const Text('Cierre de caja')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OutlinedButton.icon(
            onPressed: _selectDay,
            icon: const Icon(Icons.calendar_today),
            label: Text(formatUtcDay(context, _selectedDay)),
          ),
          const SizedBox(height: 16),
          summary.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) => Text(
              'No se pudo calcular el cierre: $error',
              textAlign: TextAlign.center,
            ),
            data: (close) => _CashCloseSummaryView(summary: close),
          ),
        ],
      ),
    );
  }
}

class _CashCloseSummaryView extends StatelessWidget {
  const _CashCloseSummaryView({required this.summary});

  static const _methods = [
    ('cash', 'Efectivo'),
    ('debit', 'Débito'),
    ('credit', 'Crédito'),
    ('transfer', 'Transferencia'),
    ('other', 'Otro'),
  ];

  final CashCloseSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  'Total del día',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '\$ ${formatMoneyCents(summary.totalCents)}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text('Ventas activas: ${summary.saleCount}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ..._methods.map(
          (method) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(method.$2),
            trailing: Text(
              '\$ ${formatMoneyCents(summary.byPaymentMethod[method.$1] ?? 0)}',
            ),
          ),
        ),
        const Divider(),
        Text(
          summary.pendingSyncCount == 0
              ? 'Todos los registros del día están sincronizados.'
              : 'Registros pendientes de sincronización: '
                    '${summary.pendingSyncCount}',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

DateTime _utcDateOnly(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);
