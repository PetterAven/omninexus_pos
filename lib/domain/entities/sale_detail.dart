/// Entidad de dominio: un renglón del detalle de una venta ya
/// registrada (a diferencia de [CartItem], este ya tiene `saleId` y,
/// una vez guardado, un `id` propio).
class SaleDetail {
  final int? id;
  final int saleId;
  final String productCode;
  final String productName;
  final double price;
  final int quantity;

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
        quantity: int.parse(map['quantity'].toString()),
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