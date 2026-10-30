import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../data/sales/sales_repository.dart';
import 'cart_provider.dart';
import 'ticket_service.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  static const _methods = [
    ('cash', 'Efectivo'),
    ('debit', 'Débito'),
    ('credit', 'Crédito'),
    ('transfer', 'Transferencia'),
    ('other', 'Otro'),
  ];

  String _paymentMethod = 'cash';
  bool _saving = false;
  final _ticketService = TicketService();

  Future<void> _confirmSale() async {
    final cart = ref.read(cartProvider);
    if (_saving || cart.items.isEmpty) {
      return;
    }

    setState(() => _saving = true);
    late final String saleId;
    try {
      saleId = await ref
          .read(salesRepositoryProvider)
          .createSale(cart: cart, paymentMethod: _paymentMethod);
    } on SaleValidationException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
      return;
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }

    ref.read(cartProvider.notifier).clear();
    if (!mounted) {
      return;
    }

    final shouldShare = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Venta guardada'),
        content: const Text('¿Compartir ticket en PDF?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Compartir'),
          ),
        ],
      ),
    );
    if (!mounted) {
      return;
    }

    String? ticketError;
    if (shouldShare == true) {
      try {
        final file = await _ticketService.generatePdf(
          saleId: saleId,
          cart: cart,
          paymentMethod: _paymentMethod,
        );
        await _ticketService.shareTicket(file);
      } on TicketException catch (error) {
        ticketError = error.message;
      }
    }

    if (mounted) {
      context.go('/');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ticketError == null
                ? 'Venta guardada sin conexión.'
                : 'Venta guardada. $ticketError',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Cobro')),
      body: cart.items.isEmpty
          ? const Center(child: Text('El carrito está vacío.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Artículos',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                ...cart.items.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.description),
                    subtitle: Text(
                      '${item.quantity} × '
                      '\$ ${formatMoneyCents(item.unitPriceCents)}',
                    ),
                    leading: IconButton(
                      tooltip: 'Quitar una unidad',
                      onPressed: () =>
                          notifier.updateQuantity(item.id, item.quantity - 1),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('\$ ${formatMoneyCents(item.subtotalCents)}'),
                        IconButton(
                          tooltip: 'Eliminar artículo',
                          onPressed: () => notifier.removeItem(item.id),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '\$ ${formatMoneyCents(cart.totalCents)}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  initialValue: _paymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Medio de pago',
                    border: OutlineInputBorder(),
                  ),
                  items: _methods
                      .map(
                        (method) => DropdownMenuItem(
                          value: method.$1,
                          child: Text(method.$2),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _paymentMethod = value);
                    }
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _confirmSale,
                  child: Text(_saving ? 'Guardando...' : 'Confirmar venta'),
                ),
              ],
            ),
    );
  }
}
