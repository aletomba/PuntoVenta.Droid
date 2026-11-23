import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../data/sales/sales_repository.dart';
import 'sale_display_formatters.dart';

class SaleDetailScreen extends ConsumerWidget {
  const SaleDetailScreen({required this.saleId, super.key});

  final String saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(saleDetailsProvider(saleId));
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de venta')),
      body: details.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('No se pudo cargar la venta: $error'),
          ),
        ),
        data: (saleDetails) {
          if (saleDetails == null) {
            return const Center(child: Text('La venta no existe.'));
          }

          final sale = saleDetails.sale;
          final isVoided = sale.status == 'voided';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Venta ${sale.id}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(formatSaleDateTime(context, sale.date)),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Estado'),
                trailing: Text(isVoided ? 'Anulada' : 'Activa'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Medio de pago'),
                trailing: Text(paymentMethodLabel(sale.paymentMethod)),
              ),
              const Divider(),
              ...saleDetails.items.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.description),
                  subtitle: Text(
                    '${item.quantity} × '
                    '\$ ${formatMoneyCents(item.unitPriceCents)}',
                  ),
                  trailing: Text(
                    '\$ ${formatMoneyCents(item.quantity * item.unitPriceCents)}',
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Total'),
                titleTextStyle: Theme.of(context).textTheme.titleLarge,
                trailing: Text(
                  '\$ ${formatMoneyCents(sale.totalCents)}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (isVoided && sale.voidReason != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Motivo de anulación'),
                  subtitle: Text(sale.voidReason!),
                ),
              if (isVoided && sale.voidedAt != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Anulada el'),
                  subtitle: Text(formatSaleDateTime(context, sale.voidedAt!)),
                ),
            ],
          );
        },
      ),
    );
  }
}
