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

class SaleDetails {
  const SaleDetails({required this.sale, required this.items});

  final Sale sale;
  final List<SaleItem> items;
}

class CashCloseSummary {
  const CashCloseSummary({
    required this.day,
    required this.totalCents,
    required this.byPaymentMethod,
    required this.saleCount,
    required this.pendingSyncCount,
  });

  factory CashCloseSummary.fromSales(DateTime day, Iterable<Sale> sales) {
    final daySales = sales
        .where((sale) => _sameUtcDay(sale.date, day))
        .toList();
    final activeSales = daySales
        .where((sale) => sale.status == 'active')
        .toList();
    final byPaymentMethod = {
      for (final method in SalesRepository.paymentMethods) method: 0,
    };
    for (final sale in activeSales) {
      byPaymentMethod.update(
        sale.paymentMethod,
        (total) => total + sale.totalCents,
        ifAbsent: () => sale.totalCents,
      );
    }

    return CashCloseSummary(
      day: DateTime.utc(day.year, day.month, day.day),
      totalCents: activeSales.fold(0, (total, sale) => total + sale.totalCents),
      byPaymentMethod: Map.unmodifiable(byPaymentMethod),
      saleCount: activeSales.length,
      pendingSyncCount: daySales.where((sale) => !sale.synced).length,
    );
  }

  final DateTime day;
  final int totalCents;
  final Map<String, int> byPaymentMethod;
  final int saleCount;
  final int pendingSyncCount;
}

class SaleAuthorizationException implements Exception {
  const SaleAuthorizationException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum SaleActorRole { admin, cashier }

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

  Stream<List<Sale>> watchSales() {
    return (_database.select(
      _database.sales,
    )..orderBy([(sale) => OrderingTerm.desc(sale.date)])).watch();
  }

  Future<SaleDetails?> getSaleDetails(String saleId) async {
    final sale = await (_database.select(
      _database.sales,
    )..where((candidate) => candidate.id.equals(saleId))).getSingleOrNull();
    if (sale == null) {
      return null;
    }

    final items = await (_database.select(
      _database.saleItems,
    )..where((item) => item.saleId.equals(saleId))).get();
    return SaleDetails(sale: sale, items: items);
  }

  Stream<CashCloseSummary> watchCashClose(DateTime day) {
    return watchSales().map((sales) => CashCloseSummary.fromSales(day, sales));
  }

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

  Future<Sale> voidSale({
    required String saleId,
    required String actorUserId,
    required SaleActorRole actorRole,
    required String reason,
  }) async {
    if (actorRole != SaleActorRole.admin) {
      throw const SaleAuthorizationException('Solo Admin puede anular ventas.');
    }

    final normalizedReason = reason.trim();
    if (actorUserId.trim().isEmpty ||
        normalizedReason.isEmpty ||
        normalizedReason.length > 500) {
      throw const SaleValidationException(
        'El usuario y el motivo de anulación son obligatorios.',
      );
    }

    final now = DateTime.now().toUtc();
    return _database.transaction(() async {
      final sale = await (_database.select(
        _database.sales,
      )..where((candidate) => candidate.id.equals(saleId))).getSingleOrNull();
      if (sale == null) {
        throw const SaleValidationException('La venta no existe.');
      }
      if (sale.status == 'voided') {
        return sale;
      }
      if (sale.status != 'active') {
        throw const SaleValidationException(
          'La venta no se puede anular en su estado actual.',
        );
      }

      final items = await (_database.select(
        _database.saleItems,
      )..where((item) => item.saleId.equals(saleId))).get();
      final quantitiesByProduct = <String, int>{};
      for (final item in items) {
        final productId = item.productId;
        if (productId != null) {
          quantitiesByProduct.update(
            productId,
            (quantity) => quantity + item.quantity,
            ifAbsent: () => item.quantity,
          );
        }
      }

      for (final entry in quantitiesByProduct.entries) {
        final product =
            await (_database.select(_database.products)
                  ..where((candidate) => candidate.id.equals(entry.key)))
                .getSingleOrNull();
        if (product == null) {
          throw const SaleValidationException(
            'No se encontró un producto de la venta.',
          );
        }
        await (_database.update(
          _database.products,
        )..where((candidate) => candidate.id.equals(entry.key))).write(
          ProductsCompanion(
            stock: Value(product.stock + entry.value),
            updatedAt: Value(now),
          ),
        );
      }

      final voidedSale = sale.copyWith(
        status: 'voided',
        voidedAt: Value(now),
        voidedByUserId: Value(actorUserId.trim()),
        voidReason: Value(normalizedReason),
        synced: false,
      );
      await (_database.update(
        _database.sales,
      )..where((candidate) => candidate.id.equals(saleId))).write(
        SalesCompanion(
          status: Value(voidedSale.status),
          voidedAt: Value(voidedSale.voidedAt),
          voidedByUserId: Value(voidedSale.voidedByUserId),
          voidReason: Value(voidedSale.voidReason),
          synced: Value(false),
        ),
      );
      return (_database.select(
        _database.sales,
      )..where((candidate) => candidate.id.equals(saleId))).getSingle();
    });
  }
}

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepository(ref.watch(appDatabaseProvider));
});

final salesHistoryProvider = StreamProvider<List<Sale>>((ref) {
  return ref.watch(salesRepositoryProvider).watchSales();
});

final saleDetailsProvider = FutureProvider.family<SaleDetails?, String>((
  ref,
  saleId,
) {
  return ref.watch(salesRepositoryProvider).getSaleDetails(saleId);
});

final cashCloseSummaryProvider =
    StreamProvider.family<CashCloseSummary, DateTime>((ref, day) {
      return ref.watch(salesRepositoryProvider).watchCashClose(day);
    });

bool _sameUtcDay(DateTime first, DateTime second) {
  final firstUtc = first.toUtc();
  final secondUtc = second.toUtc();
  return firstUtc.year == secondUtc.year &&
      firstUtc.month == secondUtc.month &&
      firstUtc.day == secondUtc.day;
}
