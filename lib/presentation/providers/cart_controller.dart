import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/product.dart';

/// Resultado de agregar/incrementar/editar un producto en el carrito. El
/// controller no conoce BuildContext ni debe conocerlo -- es la UI
/// (SalesTerminalScreen) la que decide qué SnackBar mostrar según este
/// resultado.
enum CartOperationResult {
  success,
  outOfStock, // el producto no tiene stock desde el inicio
  noMoreStock, // ya se alcanzó el stock disponible en el carrito
  invalidWeight, // se intentó agregar/editar un producto a granel con peso <= 0
  notApplicableForWeighted, // se intentó usar +/- de a 1 en un producto a granel
}

/// Estado del carrito de la Terminal de Ventas.
///
/// `quantity` en CartItem es `double`, para poder guardar tanto piezas
/// (`1.0`, `2.0`...) como pesos exactos (`1.450` kg) en productos con
/// `product.isWeighted == true`. La UI es responsable de mostrar el
/// diálogo de peso (`showWeightInputDialog`) ANTES de llamar a
/// `addProduct` con ese peso -- este controller nunca abre diálogos.
class CartController extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() => [];

  /// Para productos normales (`isWeighted == false`), `weight` se ignora
  /// y se agrega 1 pieza. Para productos a granel (`isWeighted == true`),
  /// `weight` es obligatorio y debe venir ya capturado por
  /// `showWeightInputDialog` -- este método no lo solicita.
  CartOperationResult addProduct(Product product, {double? weight}) {
    if (product.stock <= 0 && !product.isWeighted) {
      return CartOperationResult.outOfStock;
    }

    final double quantityToAdd;
    if (product.isWeighted) {
      if (weight == null || weight <= 0) {
        return CartOperationResult.invalidWeight;
      }
      quantityToAdd = weight;
    } else {
      quantityToAdd = 1.0;
    }

    final cart = state;
    final existingIndex = cart.indexWhere((item) => item.product.code == product.code);

    if (existingIndex >= 0) {
      final currentItem = cart[existingIndex];
      final newQuantity = currentItem.quantity + quantityToAdd;

      // NOTA: para productos a granel, product.stock no representa de
      // forma confiable el peso disponible, así que la validación de
      // stock se aplica solo a productos por pieza.
      if (!product.isWeighted && newQuantity > product.stock) {
        return CartOperationResult.noMoreStock;
      }

      state = [
        for (int i = 0; i < cart.length; i++)
          if (i == existingIndex)
            currentItem.copyWith(quantity: newQuantity)
          else
            cart[i],
      ];
    } else {
      state = [...cart, CartItem(product: product, quantity: quantityToAdd)];
    }
    return CartOperationResult.success;
  }

  /// Solo para productos por pieza. En productos a granel, la UI debe
  /// abrir el diálogo de peso y llamar a `updateWeight()` en vez de esto.
  CartOperationResult increaseQuantity(int index) {
    final cart = state;
    final item = cart[index];

    if (item.product.isWeighted) {
      return CartOperationResult.notApplicableForWeighted;
    }

    if (item.quantity >= item.product.stock) {
      return CartOperationResult.noMoreStock;
    }
    state = [
      for (int i = 0; i < cart.length; i++)
        if (i == index) item.copyWith(quantity: item.quantity + 1) else cart[i],
    ];
    return CartOperationResult.success;
  }

  /// Solo para productos por pieza (ver nota de increaseQuantity).
  CartOperationResult decreaseQuantity(int index) {
    final cart = state;
    final item = cart[index];

    if (item.product.isWeighted) {
      return CartOperationResult.notApplicableForWeighted;
    }

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
    return CartOperationResult.success;
  }

  /// Edita el peso exacto de un producto a granel ya agregado al
  /// carrito (ej. el cajero se equivocó al pesar y vuelve a capturar).
  /// No aplica a productos por pieza.
  CartOperationResult updateWeight(int index, double newWeight) {
    final cart = state;
    final item = cart[index];

    if (!item.product.isWeighted) {
      return CartOperationResult.notApplicableForWeighted;
    }
    if (newWeight <= 0) {
      return CartOperationResult.invalidWeight;
    }

    state = [
      for (int i = 0; i < cart.length; i++)
        if (i == index) item.copyWith(quantity: newWeight) else cart[i],
    ];
    return CartOperationResult.success;
  }

  /// Edita la cantidad exacta de un ítem del carrito -- a diferencia de
  /// increaseQuantity/decreaseQuantity (que solo suman/restan de a 1 y
  /// no aplican a productos a granel), este sirve tanto para piezas
  /// como para peso, cuando la UI ya capturó el valor final en un
  /// diálogo (ej. re-teclear el peso, o corregir una cantidad a mano).
  CartOperationResult updateQuantity(int index, double newQuantity) {
    final cart = state;
    final item = cart[index];

    if (newQuantity <= 0) {
      return CartOperationResult.invalidWeight;
    }
    if (!item.product.isWeighted && newQuantity > item.product.stock) {
      return CartOperationResult.noMoreStock;
    }

    state = [
      for (int i = 0; i < cart.length; i++)
        if (i == index) item.copyWith(quantity: newQuantity) else cart[i],
    ];
    return CartOperationResult.success;
  }

  /// Elimina un ítem del carrito sin importar su cantidad (a diferencia
  /// de decreaseQuantity, que resta de a uno y solo lo quita al llegar a
  /// 0/1). Pensado para el botón de basurero de cada renglón del carrito.
  void removeItem(int index) {
    final cart = state;
    state = [
      for (int i = 0; i < cart.length; i++)
        if (i != index) cart[i],
    ];
  }

  /// Reemplaza el carrito completo de una sola vez. Pensado para aplicar
  /// un snapshot remoto recibido de SyncRepository (Teléfono <-> PC) --
  /// a diferencia de addProduct/increaseQuantity/etc., no valida stock
  /// ni pesos: el snapshot ya representa un carrito válido tal como
  /// quedó del lado que lo mandó.
  void replaceAll(List<CartItem> items) {
    state = items;
  }

  void clear() {
    state = [];
  }
}

final cartControllerProvider = NotifierProvider<CartController, List<CartItem>>(CartController.new);

/// Derivado: total monetario del carrito. Se recalcula solo cuando
/// cartControllerProvider cambia.
final cartTotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartControllerProvider);
  double total = 0.0;
  for (final item in cart) {
    total += item.subtotal;
  }
  return total;
});