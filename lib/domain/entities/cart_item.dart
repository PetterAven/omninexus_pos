import 'product.dart';

/// Entidad de dominio: un artículo dentro del carrito de la Terminal de
/// Ventas. Envuelve el [Product] completo (no solo código/nombre/precio
/// sueltos) para no perder el resto de sus datos (stock, etc.) mientras
/// vive en el carrito, y para que `subtotal` siempre se calcule con el
/// precio vigente del producto.
class CartItem {
  final Product product;
  final int quantity;

  const CartItem({
    required this.product,
    required this.quantity,
  });

  double get subtotal => product.price * quantity;

  CartItem copyWith({Product? product, int? quantity}) => CartItem(
        product: product ?? this.product,
        quantity: quantity ?? this.quantity,
      );

  /// Usado por TicketTelegramService/TicketPdfService/showTicketReceiptDialog,
  /// que todavía reciben el carrito como lista de mapas.
  Map<String, dynamic> toMap() => {
        'code': product.code,
        'name': product.name,
        'price': product.price,
        'quantity': quantity,
        'subtotal': subtotal,
      };
}