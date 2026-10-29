import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../data/sales/sales_repository.dart';
import 'cart_provider.dart';

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

  Future<void> _confirmSale() async {
    final cart = ref.read(cartProvider);
    if (_saving || cart.items.isEmpty) {
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(salesRepositoryProvider)
          .createSale(cart: cart, paymentMethod: _paymentMethod);
      ref.read(cartProvider.notifier).clear();
      if (!mounted) {
        return;
      }
      context.go('/');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Venta guardada sin conexión.')),
      );
    } on SaleValidationException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
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
