/// Entidad de dominio: una venta (el encabezado del ticket, sin el
/// detalle de productos -- eso vive en [SaleDetail]).
class Sale {
  final int id;
  final double total;
  final String date;

  const Sale({
    required this.id,
    required this.total,
    required this.date,
  });

  factory Sale.fromMap(Map<String, dynamic> map) => Sale(
        id: map['id'] as int,
        total: double.parse(map['total'].toString()),
        date: map['date'].toString(),
      );
}
