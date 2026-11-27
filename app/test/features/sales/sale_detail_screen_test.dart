import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punto_venta/core/providers.dart';
import 'package:punto_venta/data/auth/auth_repository.dart';
import 'package:punto_venta/data/local/app_database.dart';
import 'package:punto_venta/data/sales/sales_repository.dart';
import 'package:punto_venta/features/sales/cart_provider.dart';
import 'package:punto_venta/features/sales/sale_detail_screen.dart';

void main() {
  testWidgets(
    'Admin can void a sale from its detail and the record stays local',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = SalesRepository(database);
      final saleId = await repository.createSale(
        cart: const CartState(
          items: [
            CartItem(
              id: 'free-line',
              description: 'Bolsa',
              unitPriceCents: 50,
              quantity: 1,
            ),
          ],
        ),
        paymentMethod: 'cash',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            authSessionProvider.overrideWith(
              (ref) async =>
                  const AuthSession(userId: 'admin-user', role: AuthRole.admin),
            ),
          ],
          child: MaterialApp(home: SaleDetailScreen(saleId: saleId)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Anular venta'), findsOneWidget);
      await tester.tap(find.text('Anular venta'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Error de carga');
      await tester.tap(find.text('Anular'));
      await tester.pumpAndSettle();

      final sale = await (database.select(
        database.sales,
      )..where((candidate) => candidate.id.equals(saleId))).getSingle();
      expect(sale.status, 'voided');
      expect(sale.voidReason, 'Error de carga');
      expect(sale.synced, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
    },
  );

  testWidgets('Cajero cannot see the local void action', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = SalesRepository(database);
    final saleId = await repository.createSale(
      cart: const CartState(
        items: [
          CartItem(
            id: 'free-line',
            description: 'Bolsa',
            unitPriceCents: 50,
            quantity: 1,
          ),
        ],
      ),
      paymentMethod: 'cash',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          authSessionProvider.overrideWith(
            (ref) async => const AuthSession(
              userId: 'cashier-user',
              role: AuthRole.cashier,
            ),
          ),
        ],
        child: MaterialApp(home: SaleDetailScreen(saleId: saleId)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Anular venta'), findsNothing);
    expect(find.text('Solo Admin puede anular ventas.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await database.close();
  });
}
