import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers.dart';
import '../../features/sales/cart_provider.dart';
import '../local/app_database.dart';

class SaleValidationException implements Exception {
  const SaleValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SalesRepository {
  SalesRepository(this._database);

  static const paymentMethods = {
    'cash',
    'debit',
    'credit',
    'transfer',
    'other',
  };

  final AppDatabase _database;
  final _uuid = const Uuid();

  Future<String> createSale({
    required CartState cart,
    required String paymentMethod,
    String? userId,
  }) async {
    if (cart.items.isEmpty) {
      throw const SaleValidationException('El carrito está vacío.');
    }
    if (!paymentMethods.contains(paymentMethod)) {
      throw const SaleValidationException('El medio de pago no es válido.');
    }

    final saleId = _uuid.v4();
    final now = DateTime.now().toUtc();

    await _database.transaction(() async {
      final productsById = <String, Product>{};
      final quantitiesByProduct = <String, int>{};
      var totalCents = 0;

      for (final item in cart.items) {
        if (item.quantity < 1 ||
            item.unitPriceCents < 0 ||
            item.description.trim().isEmpty) {
          throw const SaleValidationException(
            'El carrito contiene un artículo inválido.',
          );
        }
        totalCents += item.subtotalCents;
        final productId = item.productId;
        if (productId == null) {
          continue;
        }

        final product =
            productsById[productId] ??
            await (_database.select(_database.products)
                  ..where((candidate) => candidate.id.equals(productId)))
                .getSingleOrNull();
        if (product == null || product.isDeleted) {
          throw const SaleValidationException(
            'Uno de los productos ya no está disponible.',
          );
        }
        productsById[productId] = product;
        quantitiesByProduct.update(
          productId,
          (quantity) => quantity + item.quantity,
          ifAbsent: () => item.quantity,
        );
      }

      for (final entry in quantitiesByProduct.entries) {
        final product = productsById[entry.key]!;
        if (entry.value > product.stock) {
          throw SaleValidationException(
            'Stock insuficiente para ${product.name}.',
          );
        }
      }

      await _database
          .into(_database.sales)
          .insert(
            SalesCompanion.insert(
              id: saleId,
              userId: Value(userId),
              date: now,
              totalCents: totalCents,
              paymentMethod: paymentMethod,
              status: 'active',
            ),
          );

      for (final item in cart.items) {
        await _database
            .into(_database.saleItems)
            .insert(
              SaleItemsCompanion.insert(
                id: _uuid.v4(),
                saleId: saleId,
                productId: Value(item.productId),
                description: item.description.trim(),
                quantity: item.quantity,
                unitPriceCents: item.unitPriceCents,
              ),
            );
      }

      for (final entry in quantitiesByProduct.entries) {
        final product = productsById[entry.key]!;
        await (_database.update(
          _database.products,
        )..where((candidate) => candidate.id.equals(entry.key))).write(
          ProductsCompanion(
            stock: Value(product.stock - entry.value),
            updatedAt: Value(now),
          ),
        );
      }
    });

    return saleId;
  }
}

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepository(ref.watch(appDatabaseProvider));
});
