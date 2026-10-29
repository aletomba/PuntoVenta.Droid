import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../data/local/app_database.dart';
import '../../data/products/products_repository.dart';
import '../scanner/scanner_formats.dart';
import 'cart_provider.dart';

class NewSaleScreen extends ConsumerStatefulWidget {
  const NewSaleScreen({super.key});

  @override
  ConsumerState<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends ConsumerState<NewSaleScreen> {
  String _query = '';

  Future<void> _scan() async {
    final rawCode = await context.push<String>('/sales/scan');
    final code = normalizeScannedCode(rawCode);
    if (code == null || !mounted) {
      return;
    }

    final product = await ref
        .read(productsRepositoryProvider)
        .findByBarcode(code);
    if (!mounted) {
      return;
    }
    if (product == null) {
      await _createProduct(barcode: code);
    } else {
      _addToCart(product);
    }
  }

  Future<void> _createProduct({String? barcode}) async {
    final draft = await showDialog<_ProductDraft>(
      context: context,
      builder: (context) => _NewProductDialog(barcode: barcode),
    );
    if (draft == null || !mounted) {
      return;
    }

    try {
      final product = await ref
          .read(productsRepositoryProvider)
          .create(
            barcode: draft.barcode,
            name: draft.name,
            priceCents: draft.priceCents,
            stock: draft.stock,
          );
      if (mounted) {
        _addToCart(product);
      }
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _addFreeItem() async {
    final draft = await showDialog<_FreeItemDraft>(
      context: context,
      builder: (context) => const _FreeItemDialog(),
    );
    if (draft == null || !mounted) {
      return;
    }
    ref
        .read(cartProvider.notifier)
        .addFreeItem(
          description: draft.description,
          unitPriceCents: draft.priceCents,
        );
  }

  void _addToCart(Product product) {
    final added = ref.read(cartProvider.notifier).addProduct(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? 'Agregado: ${product.name}'
              : 'No hay stock disponible de ${product.name}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsListProvider);
    final cart = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva venta'),
        actions: [
          IconButton(
            tooltip: 'Agregar producto',
            onPressed: _createProduct,
            icon: const Icon(Icons.add_box_outlined),
          ),
          IconButton(
            tooltip: 'Precio libre',
            onPressed: _addFreeItem,
            icon: const Icon(Icons.price_change_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar por nombre o código',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
          ),
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error al cargar productos: $error'),
                ),
              ),
              data: (products) {
                final query = _query.toLowerCase();
                final matchingProducts = products.where((product) {
                  return product.name.toLowerCase().contains(query) ||
                      (product.barcode?.toLowerCase().contains(query) ?? false);
                }).toList();
                if (matchingProducts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        products.isEmpty
                            ? 'No hay productos. Agrega uno con el botón +.'
                            : 'No se encontraron productos.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: matchingProducts.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final product = matchingProducts[index];
                    return ListTile(
                      title: Text(product.name),
                      subtitle: Text(
                        'Stock: ${product.stock} · '
                        '${product.barcode ?? "Sin código"}',
                      ),
                      trailing: Text(
                        '\$ ${formatMoneyCents(product.priceCents)}',
                      ),
                      enabled: product.stock > 0,
                      onTap: product.stock > 0
                          ? () => _addToCart(product)
                          : null,
                    );
                  },
                );
              },
            ),
          ),
          if (cart.items.isNotEmpty)
            SafeArea(
              child: Container(
                padding: const EdgeInsets.all(12),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Artículos: ${cart.itemCount} · '
                        'Total: \$ ${formatMoneyCents(cart.totalCents)}',
                      ),
                    ),
                    FilledButton(
                      onPressed: () => context.push('/sales/checkout'),
                      child: const Text('Ir a cobrar'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scan,
        tooltip: 'Escanear código',
        child: const Icon(Icons.qr_code_scanner),
      ),
    );
  }
}

class _ProductDraft {
  const _ProductDraft({
    required this.name,
    required this.barcode,
    required this.priceCents,
    required this.stock,
  });

  final String name;
  final String? barcode;
  final int priceCents;
  final int stock;
}

class _NewProductDialog extends StatefulWidget {
  const _NewProductDialog({this.barcode});

  final String? barcode;

  @override
  State<_NewProductDialog> createState() => _NewProductDialogState();
}

class _NewProductDialogState extends State<_NewProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _barcodeController = TextEditingController(text: widget.barcode);
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController(text: '1');

  @override
  void dispose() {
    _barcodeController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      _ProductDraft(
        name: _nameController.text.trim(),
        barcode: _barcodeController.text.trim(),
        priceCents: parseMoneyToCents(_priceController.text)!,
        stock: int.parse(_stockController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar producto'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: widget.barcode == null,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ingresa un nombre.'
                    : null,
              ),
              TextField(
                controller: _barcodeController,
                decoration: const InputDecoration(
                  labelText: 'Código de barras (opcional)',
                ),
              ),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Precio',
                  prefixText: '\$ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) =>
                    value == null || parseMoneyToCents(value) == null
                    ? 'Ingresa un monto válido con hasta 2 decimales.'
                    : null,
              ),
              TextFormField(
                controller: _stockController,
                decoration: const InputDecoration(labelText: 'Stock inicial'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final stock = int.tryParse(value?.trim() ?? '');
                  return stock == null || stock < 0
                      ? 'Ingresa un stock válido.'
                      : null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Guardar y agregar'),
        ),
      ],
    );
  }
}

class _FreeItemDraft {
  const _FreeItemDraft({required this.description, required this.priceCents});

  final String description;
  final int priceCents;
}

class _FreeItemDialog extends StatefulWidget {
  const _FreeItemDialog();

  @override
  State<_FreeItemDialog> createState() => _FreeItemDialogState();
}

class _FreeItemDialogState extends State<_FreeItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      _FreeItemDraft(
        description: _descriptionController.text.trim(),
        priceCents: parseMoneyToCents(_priceController.text)!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Precio libre'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Descripción'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Ingresa una descripción.'
                  : null,
            ),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Monto',
                prefixText: '\$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) =>
                  value == null || parseMoneyToCents(value) == null
                  ? 'Ingresa un monto válido con hasta 2 decimales.'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Agregar')),
      ],
    );
  }
}
