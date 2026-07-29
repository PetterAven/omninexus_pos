import 'product.dart';

/// Entidad de dominio: un artículo dentro del carrito de la Terminal de
/// Ventas.
///
/// v1.1.0: `quantity` pasa de `int` a `double` para poder representar
/// tanto piezas enteras (`1.0`, `2.0`, productos con `isWeighted == false`)
/// como pesos exactos (`1.450` kg, productos con `isWeighted == true`).
class CartItem {
  final Product product;
  final double quantity;

  const CartItem({
    required this.product,
    required this.quantity,
  });

  double get subtotal => product.price * quantity;

  CartItem copyWith({Product? product, double? quantity}) => CartItem(
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
        'unit': product.unit,
        'subtotal': subtotal,
      };
}