/// Entidad de dominio: representa un producto tal como existe en la
/// tabla `products` (columna `code` como identificador).
///
/// v1.1.0: se agregan `isWeighted` y `unit` para soportar venta a granel
/// (ej. huevo, jamón, fruta cobrados por peso en vez de por pieza), y
/// `stock` pasa de `int` a `double` -- así sirve tanto para contar
/// piezas enteras (5, 20...) como para representar kilos/litros en
/// existencia de un producto a granel (ej. 3.5 kg de queso).
class Product {
  final String code;
  final String name;
  final double price;
  final double stock;
  final bool isWeighted;
  final String unit;

  const Product({
    required this.code,
    required this.name,
    required this.price,
    required this.stock,
    this.isWeighted = false,
    this.unit = 'pza',
  });

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        code: map['code'].toString(),
        name: map['name'].toString(),
        price: double.parse(map['price'].toString()),
        stock: double.parse(map['stock'].toString()),
        // SQLite guarda booleanos como INTEGER (0/1); Supabase puede
        // regresar el valor ya como bool. Se cubren ambos casos, y si la
        // columna no existe aún en una fila vieja, cae en `false`.
        isWeighted: map['is_weighted'] == true || map['is_weighted']?.toString() == '1',
        unit: map['unit']?.toString() ?? 'pza',
      );

  Map<String, dynamic> toMap() => {
        'code': code,
        'name': name,
        'price': price,
        'stock': stock,
        'is_weighted': isWeighted ? 1 : 0,
        'unit': unit,
      };

  Product copyWith({
    String? code,
    String? name,
    double? price,
    double? stock,
    bool? isWeighted,
    String? unit,
  }) =>
      Product(
        code: code ?? this.code,
        name: name ?? this.name,
        price: price ?? this.price,
        stock: stock ?? this.stock,
        isWeighted: isWeighted ?? this.isWeighted,
        unit: unit ?? this.unit,
      );
}