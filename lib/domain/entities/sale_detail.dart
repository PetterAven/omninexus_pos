/// Entidad de dominio: una línea del detalle de una venta (un producto
/// vendido dentro de un ticket, con su cantidad y precio al momento de
/// la venta).
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
}
