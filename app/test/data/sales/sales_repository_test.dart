import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:punto_venta/data/local/app_database.dart';
import 'package:punto_venta/data/products/products_repository.dart';
import 'package:punto_venta/data/sales/sales_repository.dart';
import 'package:punto_venta/features/sales/cart_provider.dart';

void main() {
  late AppDatabase database;
  late ProductsRepository productsRepository;
  late SalesRepository salesRepository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    productsRepository = ProductsRepository(database);
    salesRepository = SalesRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('saves product and free items and deducts stock atomically', () async {
    final product = await productsRepository.create(
      barcode: '779000000001',
      name: 'Yerba',
      priceCents: 1250,
      stock: 3,
    );
    final cart = CartState(
      items: [
        CartItem(
          id: 'product-line',
          productId: product.id,
          description: product.name,
          unitPriceCents: product.priceCents,
          quantity: 2,
          product: product,
        ),
        const CartItem(
          id: 'free-line',
          description: 'Bolsa',
          unitPriceCents: 50,
          quantity: 1,
        ),
      ],
    );

    final saleId = await salesRepository.createSale(
      cart: cart,
      paymentMethod: 'cash',
    );

    final sale = await (database.select(
      database.sales,
    )..where((sale) => sale.id.equals(saleId))).getSingle();
    final items = await (database.select(
      database.saleItems,
    )..where((item) => item.saleId.equals(saleId))).get();
    final updatedProduct = await (database.select(
      database.products,
    )..where((item) => item.id.equals(product.id))).getSingle();

    expect(sale.totalCents, 2550);
    expect(sale.paymentMethod, 'cash');
    expect(sale.status, 'active');
    expect(sale.synced, isFalse);
    expect(items, hasLength(2));
    expect(
      items.singleWhere((item) => item.description == 'Bolsa').productId,
      isNull,
    );
    expect(updatedProduct.stock, 1);
  });

  test(
    'rolls back the full sale when any product has insufficient stock',
    () async {
      final available = await productsRepository.create(
        name: 'Disponible',
        priceCents: 100,
        stock: 4,
      );
      final unavailable = await productsRepository.create(
        name: 'Sin stock',
        priceCents: 200,
        stock: 0,
      );
      final cart = CartState(
        items: [
          CartItem(
            id: 'available-line',
            productId: available.id,
            description: available.name,
            unitPriceCents: available.priceCents,
            quantity: 1,
          ),
          CartItem(
            id: 'unavailable-line',
            productId: unavailable.id,
            description: unavailable.name,
            unitPriceCents: unavailable.priceCents,
            quantity: 1,
          ),
        ],
      );

      await expectLater(
        salesRepository.createSale(cart: cart, paymentMethod: 'debit'),
        throwsA(isA<SaleValidationException>()),
      );

      expect(await database.select(database.sales).get(), isEmpty);
      expect(await database.select(database.saleItems).get(), isEmpty);
      final updatedAvailable = await (database.select(
        database.products,
      )..where((product) => product.id.equals(available.id))).getSingle();
      expect(updatedAvailable.stock, 4);
      final updatedUnavailable = await (database.select(
        database.products,
      )..where((product) => product.id.equals(unavailable.id))).getSingle();
      expect(updatedUnavailable.stock, 0);
    },
  );

  test(
    'rejects a product deleted before sale and preserves database state',
    () async {
      final product = await productsRepository.create(
        name: 'Producto eliminado',
        priceCents: 500,
        stock: 3,
      );
      await (database.update(database.products)
            ..where((candidate) => candidate.id.equals(product.id)))
          .write(const ProductsCompanion(isDeleted: Value(true)));
      final cart = CartState(
        items: [
          CartItem(
            id: 'deleted-line',
            productId: product.id,
            description: product.name,
            unitPriceCents: product.priceCents,
            quantity: 1,
          ),
        ],
      );

      await expectLater(
        salesRepository.createSale(cart: cart, paymentMethod: 'cash'),
        throwsA(isA<SaleValidationException>()),
      );

      expect(await database.select(database.sales).get(), isEmpty);
      expect(await database.select(database.saleItems).get(), isEmpty);
      final unchangedProduct = await (database.select(
        database.products,
      )..where((candidate) => candidate.id.equals(product.id))).getSingle();
      expect(unchangedProduct.stock, 3);
      expect(unchangedProduct.isDeleted, isTrue);
    },
  );

  test('rejects empty carts and unsupported payment methods', () async {
    await expectLater(
      salesRepository.createSale(
        cart: const CartState(),
        paymentMethod: 'cash',
      ),
      throwsA(isA<SaleValidationException>()),
    );

    final cart = CartState(
      items: const [
        CartItem(
          id: 'free-line',
          description: 'Servicio',
          unitPriceCents: 100,
          quantity: 1,
        ),
      ],
    );
    await expectLater(
      salesRepository.createSale(cart: cart, paymentMethod: 'card'),
      throwsA(isA<SaleValidationException>()),
    );
    expect(await database.select(database.sales).get(), isEmpty);
  });

  test('loads a sale with its line items for the detail view', () async {
    final saleId = await salesRepository.createSale(
      cart: const CartState(
        items: [
          CartItem(
            id: 'free-line',
            description: 'Bolsa',
            unitPriceCents: 50,
            quantity: 2,
          ),
        ],
      ),
      paymentMethod: 'cash',
    );

    final details = await salesRepository.getSaleDetails(saleId);

    expect(details, isNotNull);
    expect(details!.sale.totalCents, 100);
    expect(details.sale.paymentMethod, 'cash');
    expect(details.items, hasLength(1));
    expect(details.items.single.description, 'Bolsa');
    expect(await salesRepository.getSaleDetails('missing'), isNull);
  });

  test(
    'cash close totals active sales by UTC day and payment method',
    () async {
      await database.batch((batch) {
        batch.insertAll(database.sales, [
          SalesCompanion.insert(
            id: 'cash-sale',
            date: DateTime.utc(2026, 1, 1, 23, 30),
            totalCents: 125,
            paymentMethod: 'cash',
            status: 'active',
            synced: const Value(true),
          ),
          SalesCompanion.insert(
            id: 'transfer-sale',
            date: DateTime.utc(2026, 1, 1, 2),
            totalCents: 75,
            paymentMethod: 'transfer',
            status: 'active',
            synced: const Value(false),
          ),
          SalesCompanion.insert(
            id: 'voided-sale',
            date: DateTime.utc(2026, 1, 1, 3),
            totalCents: 900,
            paymentMethod: 'cash',
            status: 'voided',
            synced: const Value(false),
          ),
          SalesCompanion.insert(
            id: 'next-utc-day-sale',
            date: DateTime.utc(2026, 1, 2, 1),
            totalCents: 250,
            paymentMethod: 'debit',
            status: 'active',
            synced: const Value(false),
          ),
        ]);
      });

      final summary = await salesRepository
          .watchCashClose(DateTime.utc(2026, 1, 1))
          .first;

      expect(summary.totalCents, 200);
      expect(summary.saleCount, 2);
      expect(summary.byPaymentMethod['cash'], 125);
      expect(summary.byPaymentMethod['transfer'], 75);
      expect(summary.byPaymentMethod['debit'], 0);
      expect(summary.pendingSyncCount, 2);
    },
  );

  test('rejects duplicate product barcodes locally', () async {
    await productsRepository.create(
      barcode: '779000000001',
      name: 'Yerba',
      priceCents: 1250,
      stock: 3,
    );

    await expectLater(
      productsRepository.create(
        barcode: '779000000001',
        name: 'Yerba duplicada',
        priceCents: 1250,
        stock: 3,
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
