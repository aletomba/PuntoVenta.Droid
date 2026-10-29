import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/local/app_database.dart';

class CartItem {
  const CartItem({
    required this.id,
    this.productId,
    required this.description,
    required this.unitPriceCents,
    required this.quantity,
    this.product,
  });

  final String id;
  final String? productId;
  final String description;
  final int unitPriceCents;
  final int quantity;
  final Product? product;

  int get subtotalCents => unitPriceCents * quantity;

  CartItem copyWith({required int quantity}) {
    return CartItem(
      id: id,
      productId: productId,
      description: description,
      unitPriceCents: unitPriceCents,
      quantity: quantity,
      product: product,
    );
  }
}

class CartState {
  const CartState({this.items = const []});

  final List<CartItem> items;

  int get totalCents =>
      items.fold(0, (total, item) => total + item.subtotalCents);

  int get itemCount => items.fold(0, (total, item) => total + item.quantity);
}

class CartNotifier extends Notifier<CartState> {
  final _uuid = const Uuid();

  @override
  CartState build() => const CartState();

  bool addProduct(Product product) {
    final index = state.items.indexWhere(
      (item) => item.productId == product.id,
    );
    final quantity = index < 0 ? 0 : state.items[index].quantity;
    if (product.isDeleted || quantity >= product.stock) {
      return false;
    }

    if (index >= 0) {
      final items = [...state.items];
      items[index] = items[index].copyWith(quantity: quantity + 1);
      state = CartState(items: items);
    } else {
      state = CartState(
        items: [
          ...state.items,
          CartItem(
            id: _uuid.v4(),
            productId: product.id,
            description: product.name,
            unitPriceCents: product.priceCents,
            quantity: 1,
            product: product,
          ),
        ],
      );
    }
    return true;
  }

  void addFreeItem({required String description, required int unitPriceCents}) {
    final normalizedDescription = description.trim();
    if (normalizedDescription.isEmpty || unitPriceCents < 0) {
      return;
    }
    state = CartState(
      items: [
        ...state.items,
        CartItem(
          id: _uuid.v4(),
          description: normalizedDescription,
          unitPriceCents: unitPriceCents,
          quantity: 1,
        ),
      ],
    );
  }

  bool updateQuantity(String itemId, int quantity) {
    if (quantity <= 0) {
      removeItem(itemId);
      return true;
    }
    final index = state.items.indexWhere((item) => item.id == itemId);
    if (index < 0) {
      return false;
    }
    final item = state.items[index];
    if (item.product != null && quantity > item.product!.stock) {
      return false;
    }
    final items = [...state.items];
    items[index] = item.copyWith(quantity: quantity);
    state = CartState(items: items);
    return true;
  }

  void removeItem(String itemId) {
    state = CartState(
      items: state.items.where((item) => item.id != itemId).toList(),
    );
  }

  void clear() {
    state = const CartState();
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(
  CartNotifier.new,
);
