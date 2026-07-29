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
        id: (map['id'] as num).toInt(),
        total: (map['total'] as num).toDouble(),
        date: map['date'].toString(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'total': total,
        'date': date,
      };
}