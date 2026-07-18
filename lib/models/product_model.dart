class Product {
  final String barcode;
  final String name;
  final double price;
  final String imageUrl; // <-- Nueva propiedad para la foto

  Product({
    required this.barcode,
    required this.name,
    required this.price,
    this.imageUrl = '', // Por defecto vacía
  });
}