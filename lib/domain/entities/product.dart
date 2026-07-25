/// Entidad de dominio: representa un producto tal como existe en la
/// tabla `products` (columna `code` como identificador). El modelo
/// anterior en lib/models/product_model.dart tenía campos (`id`,
/// `stock` con otro significado, `category`, `imageUrl`) que no
/// correspondían a la tabla real y no se usaba en ninguna parte del
/// código -- este reemplaza a ese.
class Product {
  final String code;
  final String name;
  final double price;
  final int stock;

  const Product({
    required this.code,
    required this.name,
    required this.price,
    required this.stock,
  });

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        code: map['code'].toString(),
        name: map['name'].toString(),
        price: double.parse(map['price'].toString()),
        stock: int.parse(map['stock'].toString()),
      );

  Map<String, dynamic> toMap() => {
        'code': code,
        'name': name,
        'price': price,
        'stock': stock,
      };
}
