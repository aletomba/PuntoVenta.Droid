import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../data/sales/sales_repository.dart';
import 'sale_display_formatters.dart';

class SalesHistoryScreen extends ConsumerWidget {
  const SalesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sales = ref.watch(salesHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de ventas')),
      body: sales.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('No se pudo cargar el historial: $error'),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No hay ventas registradas.'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final sale = items[index];
              final status = sale.status == 'voided' ? 'Anulada' : 'Activa';
              final syncStatus = sale.synced
                  ? 'Sincronizada'
                  : 'Pendiente de sincronizar';
              final shortId = sale.id.length > 8
                  ? sale.id.substring(0, 8)
                  : sale.id;
              return ListTile(
                title: Text('Venta $shortId'),
                subtitle: Text(
                  '${formatSaleDateTime(context, sale.date)} · '
                  '${paymentMethodLabel(sale.paymentMethod)} · '
                  '$status · $syncStatus',
                ),
                trailing: Text('\$ ${formatMoneyCents(sale.totalCents)}'),
                onTap: () => context.push('/sales/detail/${sale.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
