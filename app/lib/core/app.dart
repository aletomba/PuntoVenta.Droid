import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/products/product_form_screen.dart';
import '../features/products/products_list_screen.dart';
import '../features/sales/checkout_screen.dart';
import '../features/sales/new_sale_screen.dart';
import '../features/scanner/scanner_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/sales/new',
        builder: (context, state) => const NewSaleScreen(),
      ),
      GoRoute(
        path: '/sales/checkout',
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '/sales/scan',
        builder: (context, state) => const ScannerScreen(),
      ),
      GoRoute(
        path: '/scan',
        builder: (context, state) => const ScannerScreen(),
      ),
      GoRoute(
        path: '/products',
        builder: (context, state) => const ProductsListScreen(),
      ),
      GoRoute(
        path: '/products/new',
        builder: (context, state) => const ProductFormScreen(),
      ),
      GoRoute(
        path: '/products/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ProductFormScreen(productId: id);
        },
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class PuntoVentaApp extends ConsumerWidget {
  const PuntoVentaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Punto de Venta',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      routerConfig: ref.watch(routerProvider),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _openScanner(BuildContext context) async {
    final code = await context.push<String>('/scan');
    if (code == null || !context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Código escaneado: $code')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Punto de Venta')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              onPressed: () => context.push('/sales/new'),
              icon: const Icon(Icons.point_of_sale),
              label: const Text('Nueva venta'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openScanner(context),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Escanear código'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push('/products'),
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Productos'),
            ),
            const SizedBox(height: 16),
            const Text('Base de la aplicación lista'),
          ],
        ),
      ),
    );
  }
}
