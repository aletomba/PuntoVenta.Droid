import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/products/products_repository.dart';

class ProductsListScreen extends ConsumerWidget {
  const ProductsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/products/new'),
        child: const Icon(Icons.add),
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (products) {
          if (products.isEmpty) {
            return const Center(
              child: Text('Sin productos. Agregá uno con el botón +'),
            );
          }

          return ListView.separated(
            itemCount: products.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final product = products[index];
              final price = (product.priceCents / 100).toStringAsFixed(2);
              return ListTile(
                title: Text(product.name),
                subtitle: Text(
                  'Código: ${product.barcode ?? "Sin código"} • Stock: ${product.stock}',
                ),
                trailing: Text('\$ $price'),
                onTap: () => context.push('/products/${product.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
