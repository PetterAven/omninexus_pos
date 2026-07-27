import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/product.dart';

/// Resultado de agregar/incrementar un producto en el carrito. El
/// controller no conoce BuildContext ni debe conocerlo -- es la UI
/// (SalesTerminalScreen) la que decide qué SnackBar mostrar según este
/// resultado.
enum CartOperationResult {
  success,
  outOfStock, // el producto no tiene stock desde el inicio
  noMoreStock, // ya se alcanzó el stock disponible en el carrito
}

/// Estado del carrito de la Terminal de Ventas.
///
/// Extraído de `_SalesTerminalScreenState`: antes vivía como
/// `List<CartItem> _cart` + `_addProductToCart`/`_calculateTotal` dentro
/// del State. Ahora es un Notifier para que el carrito no dependa de que
/// SalesTerminalScreen siga montado, y para que cualquier otro punto de
/// entrada (código de barras, sincronización remota, checkout) lea/mute
/// el mismo estado sin pasar por callbacks del widget.
class CartController extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() => [];

  CartOperationResult addProduct(Product product) {
    if (product.stock <= 0) return CartOperationResult.outOfStock;

    final cart = state;
    final existingIndex = cart.indexWhere((item) => item.product.code == product.code);

    if (existingIndex >= 0) {
      final currentItem = cart[existingIndex];
      if (currentItem.quantity >= product.stock) {
        return CartOperationResult.noMoreStock;
      }
      state = [
        for (int i = 0; i < cart.length; i++)
          if (i == existingIndex)
            currentItem.copyWith(quantity: currentItem.quantity + 1)
          else
            cart[i],
      ];
    } else {
      state = [...cart, CartItem(product: product, quantity: 1)];
    }
    return CartOperationResult.success;
  }

  CartOperationResult increaseQuantity(int index) {
    final cart = state;
    final item = cart[index];
    if (item.quantity >= item.product.stock) {
      return CartOperationResult.noMoreStock;
    }
    state = [
      for (int i = 0; i < cart.length; i++)
        if (i == index) item.copyWith(quantity: item.quantity + 1) else cart[i],
    ];
    return CartOperationResult.success;
  }

  void decreaseQuantity(int index) {
    final cart = state;
    final item = cart[index];
    if (item.quantity > 1) {
      state = [
        for (int i = 0; i < cart.length; i++)
          if (i == index) item.copyWith(quantity: item.quantity - 1) else cart[i],
      ];
    } else {
      state = [
        for (int i = 0; i < cart.length; i++)
          if (i != index) cart[i],
      ];
    }
  }

  void clear() {
    state = [];
  }
}

final cartControllerProvider = NotifierProvider<CartController, List<CartItem>>(CartController.new);

/// Derivado: total monetario del carrito. Antes cada pantalla que lo
/// necesitaba recalculaba a mano sumando item.subtotal (ver
/// `_calculateTotal` original); ahora se lee directo de aquí y se
/// recalcula solo cuando cartControllerProvider cambia.
final cartTotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartControllerProvider);
  double total = 0.0;
  for (final item in cart) {
    total += item.subtotal;
  }
  return total;
});