import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers.dart';
import '../local/app_database.dart';

class ProductsRepository {
  ProductsRepository(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();

  Future<List<Product>> list() {
    return (_db.select(_db.products)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]))
        .get();
  }

  Stream<List<Product>> watchAll() {
    return (_db.select(_db.products)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]))
        .watch();
  }

  Future<Product?> findByBarcode(String barcode) {
    return (_db.select(_db.products)
          ..where((tbl) => tbl.barcode.equals(barcode) & tbl.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  Future<void> upsert({
    String? id,
    String? barcode,
    required String name,
    required int priceCents,
    required int stock,
  }) async {
    final now = DateTime.now().toUtc();
    final productId = id ?? _uuid.v4();
    final normalizedBarcode = barcode?.trim().isEmpty == true ? null : barcode?.trim();

    await _db.into(_db.products).insertOnConflictUpdate(
          ProductsCompanion(
            id: Value(productId),
            barcode: Value(normalizedBarcode),
            name: Value(name.trim()),
            priceCents: Value(priceCents),
            stock: Value(stock),
            updatedAt: Value(now),
            isDeleted: const Value(false),
          ),
        );
  }

  Future<void> softDelete(String id) async {
    await (_db.update(_db.products)..where((tbl) => tbl.id.equals(id))).write(
      ProductsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }
}

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ProductsRepository(db);
});

final productsListProvider = StreamProvider<List<Product>>((ref) {
  final repo = ref.watch(productsRepositoryProvider);
  return repo.watchAll();
});
