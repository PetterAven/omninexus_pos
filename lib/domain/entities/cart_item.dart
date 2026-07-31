import 'product.dart';

/// Entidad de dominio: un artículo dentro del carrito de la Terminal de
/// Ventas.
///
/// `quantity` es `double` para poder representar tanto piezas enteras
/// (`1.0`, `2.0`, `isWeighted == false`) como pesos exactos (`1.450` kg,
/// `isWeighted == true`).
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

  /// Usado por TicketTelegramService/TicketPdfService/showTicketReceiptDialog
  /// y por SyncRepository.sendCartSnapshot() para mandar el carrito completo
  /// al dispositivo emparejado.
  ///
  /// CORREGIDO: se agregaron 'stock' y 'is_weighted' -- sin ellos, el
  /// dispositivo que recibe un snapshot remoto no podía reconstruir un
  /// Product completo vía Product.fromMap() (un producto a granel llegaba
  /// como si no lo fuera, y el stock se perdía).
  Map<String, dynamic> toMap() => {
        'code': product.code,
        'name': product.name,
        'price': product.price,
        'stock': product.stock,
        'is_weighted': product.isWeighted ? 1 : 0,
        'unit': product.unit,
        'quantity': quantity,
        'subtotal': subtotal,
      };
}