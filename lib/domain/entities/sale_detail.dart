/// Entidad de dominio: un renglón del detalle de una venta ya
/// registrada (a diferencia de [CartItem], este ya tiene `saleId` y,
/// una vez guardado, un `id` propio).
///
/// v1.1.0: `quantity` pasa de `int` a `double`, igual que en [CartItem],
/// para no perder precisión al vender productos a granel (ej. 1.450 kg
/// de queso). Antes de este cambio, se estaba usando `.round()` al
/// registrar la venta -- eso truncaba el peso real a un entero y
/// descontaba mal el stock (1.450 kg se guardaba y descontaba como 1).
class SaleDetail {
  final int? id;
  final int saleId;
  final String productCode;
  final String productName;
  final double price;
  final double quantity;

  const SaleDetail({
    this.id,
    required this.saleId,
    required this.productCode,
    required this.productName,
    required this.price,
    required this.quantity,
  });

  factory SaleDetail.fromMap(Map<String, dynamic> map) => SaleDetail(
        id: map['id'] as int?,
        saleId: map['sale_id'] as int,
        productCode: map['product_code'].toString(),
        productName: map['product_name'].toString(),
        price: double.parse(map['price'].toString()),
        quantity: double.parse(map['quantity'].toString()),
      );

  /// Incluye `id`. Úsalo cuando el renglón ya existe (p.ej. al sincronizar
  /// detalles que vienen de Supabase y se van a insertar/reemplazar en
  /// SQLite local con ConflictAlgorithm.replace).
  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'sale_id': saleId,
        'product_code': productCode,
        'product_name': productName,
        'price': price,
        'quantity': quantity,
      };

  /// Sin `id`. Úsalo al insertar un renglón nuevo (Supabase autogenera
  /// el id, y SQLite lo autoincrementa).
  Map<String, dynamic> toInsertMap() => {
        'sale_id': saleId,
        'product_code': productCode,
        'product_name': productName,
        'price': price,
        'quantity': quantity,
      };
}