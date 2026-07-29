import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninexus_pos/domain/entities/cart_item.dart';
import 'package:omninexus_pos/domain/entities/product.dart';
import 'package:omninexus_pos/presentation/providers/cart_controller.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  final refresco = const Product(code: 'T001', name: 'Refresco', price: 18.50, stock: 5);
  final soloUno = const Product(code: 'T002', name: 'Ítem con stock 1', price: 10.0, stock: 1);
  final sinStock = const Product(code: 'T003', name: 'Sin stock', price: 20.0, stock: 0);

  group('CartController.addProduct', () {
    test('agrega un producto nuevo con cantidad 1', () {
      final notifier = container.read(cartControllerProvider.notifier);

      final result = notifier.addProduct(refresco);

      expect(result, CartOperationResult.success);
      final cart = container.read(cartControllerProvider);
      expect(cart.length, 1);
      expect(cart.first.product.code, 'T001');
      expect(cart.first.quantity, 1);
    });

    test('agregar el mismo producto dos veces incrementa la cantidad, no duplica la fila', () {
      final notifier = container.read(cartControllerProvider.notifier);

      notifier.addProduct(refresco);
      final result = notifier.addProduct(refresco);

      expect(result, CartOperationResult.success);
      final cart = container.read(cartControllerProvider);
      expect(cart.length, 1);
      expect(cart.first.quantity, 2);
    });

    test('producto sin stock desde el inicio devuelve outOfStock y no toca el carrito', () {
      final notifier = container.read(cartControllerProvider.notifier);

      final result = notifier.addProduct(sinStock);

      expect(result, CartOperationResult.outOfStock);
      expect(container.read(cartControllerProvider), isEmpty);
    });

    test('llegar al límite de stock devuelve noMoreStock y no incrementa más', () {
      final notifier = container.read(cartControllerProvider.notifier);

      notifier.addProduct(soloUno);
      final result = notifier.addProduct(soloUno);

      expect(result, CartOperationResult.noMoreStock);
      final cart = container.read(cartControllerProvider);
      expect(cart.length, 1);
      expect(cart.first.quantity, 1);
    });
  });

  group('CartController.increaseQuantity / decreaseQuantity / removeItem', () {
    test('increaseQuantity sube la cantidad si hay stock disponible', () {
      final notifier = container.read(cartControllerProvider.notifier);
      notifier.addProduct(refresco);

      final result = notifier.increaseQuantity(0);

      expect(result, CartOperationResult.success);
      expect(container.read(cartControllerProvider).first.quantity, 2);
    });

    test('increaseQuantity devuelve noMoreStock al llegar al stock máximo', () {
      final notifier = container.read(cartControllerProvider.notifier);
      notifier.addProduct(soloUno);

      final result = notifier.increaseQuantity(0);

      expect(result, CartOperationResult.noMoreStock);
      expect(container.read(cartControllerProvider).first.quantity, 1);
    });

    test('decreaseQuantity resta uno si la cantidad es mayor a 1', () {
      final notifier = container.read(cartControllerProvider.notifier);
      notifier.addProduct(refresco);
      notifier.addProduct(refresco);

      notifier.decreaseQuantity(0);

      final cart = container.read(cartControllerProvider);
      expect(cart.length, 1);
      expect(cart.first.quantity, 1);
    });

    test('decreaseQuantity elimina el ítem si la cantidad era 1', () {
      final notifier = container.read(cartControllerProvider.notifier);
      notifier.addProduct(refresco);

      notifier.decreaseQuantity(0);

      expect(container.read(cartControllerProvider), isEmpty);
    });

    test('removeItem elimina el ítem sin importar la cantidad', () {
      final notifier = container.read(cartControllerProvider.notifier);
      notifier.addProduct(refresco);
      notifier.addProduct(refresco); // cantidad 2

      notifier.removeItem(0);

      expect(container.read(cartControllerProvider), isEmpty);
    });
  });

  test('clear() vacía el carrito por completo', () {
    final notifier = container.read(cartControllerProvider.notifier);
    notifier.addProduct(refresco);
    notifier.addProduct(soloUno);

    notifier.clear();

    expect(container.read(cartControllerProvider), isEmpty);
  });

  group('cartTotalProvider', () {
    test('suma los subtotales de todos los ítems del carrito', () {
      final notifier = container.read(cartControllerProvider.notifier);
      notifier.addProduct(refresco);
      notifier.addProduct(soloUno);

      final total = container.read(cartTotalProvider);

      expect(total, closeTo(28.50, 0.001));
    });

    test('se recalcula solo al cambiar el carrito (reactividad de Riverpod)', () {
      expect(container.read(cartTotalProvider), 0.0);

      container.read(cartControllerProvider.notifier).addProduct(refresco);

      expect(container.read(cartTotalProvider), closeTo(18.50, 0.001));
    });
  });

  test('CartItem.subtotal se calcula como price * quantity', () {
    final item = CartItem(product: refresco, quantity: 3);
    expect(item.subtotal, closeTo(55.50, 0.001));
  });
}