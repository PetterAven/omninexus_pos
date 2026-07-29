import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/product.dart';

enum CartOperationResult {
  success,
  outOfStock,
  noMoreStock,
  invalidWeight,
  notApplicableForWeighted,
}

class CartController extends StateNotifier<List<CartItem>> {
  CartController() : super([]);

  /// Agrega un producto al carrito contemplando cantidades por peso o unidad.
  CartOperationResult addProduct(
    Product product, {
    double quantity = 1.0,
  }) {
    if (quantity <= 0) {
      return CartOperationResult.invalidWeight;
    }

    // Se usa 'code' para identificar el producto de forma única
    final existingIndex = state.indexWhere((i) => i.product.code == product.code);
    final currentQuantity = existingIndex != -1 ? state[existingIndex].quantity : 0.0;
    final newQuantity = currentQuantity + quantity;

    if (product.stock < newQuantity) {
      return existingIndex != -1
          ? CartOperationResult.noMoreStock
          : CartOperationResult.outOfStock;
    }

    final updatedItems = List<CartItem>.from(state);

    if (existingIndex != -1) {
      final existingItem = updatedItems[existingIndex];
      updatedItems[existingIndex] = existingItem.copyWith(
        quantity: newQuantity,
      );
    } else {
      updatedItems.add(
        CartItem(
          product: product,
          quantity: quantity,
        ),
      );
    }

    state = updatedItems;
    return CartOperationResult.success;
  }

  /// Incrementa en 1 la cantidad del ítem en el índice indicado.
  CartOperationResult increaseQuantity(int index) {
    if (index < 0 || index >= state.length) {
      return CartOperationResult.invalidWeight;
    }

    final item = state[index];
    final newQuantity = item.quantity + 1.0;

    if (item.product.stock < newQuantity) {
      return CartOperationResult.noMoreStock;
    }

    final updatedList = List<CartItem>.from(state);
    updatedList[index] = item.copyWith(quantity: newQuantity);
    state = updatedList;

    return CartOperationResult.success;
  }

  /// Decrementa en 1 la cantidad del ítem en el índice indicado o lo elimina si llega a 0.
  void decreaseQuantity(int index) {
    if (index < 0 || index >= state.length) return;

    final item = state[index];
    if (item.quantity > 1.0) {
      final updatedList = List<CartItem>.from(state);
      updatedList[index] = item.copyWith(quantity: item.quantity - 1.0);
      state = updatedList;
    } else {
      removeItem(index);
    }
  }

  /// Remueve completamente un ítem por índice
  void removeItem(int index) {
    final updatedList = List<CartItem>.from(state);
    if (index >= 0 && index < updatedList.length) {
      updatedList.removeAt(index);
      state = updatedList;
    }
  }

  /// Actualiza la cantidad directamente
  void updateQuantity(int index, double quantity) {
    if (quantity <= 0) {
      removeItem(index);
      return;
    }

    if (index >= 0 && index < state.length) {
      final updatedList = List<CartItem>.from(state);
      updatedList[index] = updatedList[index].copyWith(quantity: quantity);
      state = updatedList;
    }
  }

  /// Vacía el carrito por completo
  void clear() {
    state = [];
  }

  /// Alias por compatibilidad
  void clearCart() => clear();
}

final cartControllerProvider =
    StateNotifierProvider<CartController, List<CartItem>>((ref) {
  return CartController();
});

/// Total acumulado derivado directamente del carrito
final cartTotalProvider = Provider<double>((ref) {
  final cartItems = ref.watch(cartControllerProvider);
  return cartItems.fold(0.0, (sum, item) => sum + item.subtotal);
});