import 'package:flutter/material.dart';
import '../../../data/repositories/product_repository.dart';

/// Sección de "buscador de productos + carrito" de la Terminal de
/// Ventas. Se usa tanto en el layout ancho (PC/tablet) como en el
/// angosto (teléfono) -- por eso el parámetro [expandCart].
///
/// Extraído de `SalesTerminalScreen._buildSearchAndCart`. La búsqueda de
/// productos (`ProductRepository.searchProducts`) se queda aquí dentro
/// porque es una simple lectura que no afecta el estado del carrito; en
/// cambio, cualquier cosa que modifique el carrito (agregar, subir/bajar
/// cantidad) sale por callback, porque ese estado vive en el padre
/// (`_SalesTerminalScreenState`), no en este widget.
class CartAndSearchSection extends StatelessWidget {
  final bool expandCart;
  final SearchController searchController;
  final List<Map<String, dynamic>> cart;
  final void Function(Map<String, dynamic> product) onAddProductToCart;
  final VoidCallback onScanBarcode;
  final void Function(int index) onIncreaseQuantity;
  final void Function(int index) onDecreaseQuantity;

  const CartAndSearchSection({
    super.key,
    required this.expandCart,
    required this.searchController,
    required this.cart,
    required this.onAddProductToCart,
    required this.onScanBarcode,
    required this.onIncreaseQuantity,
    required this.onDecreaseQuantity,
  });

  @override
  Widget build(BuildContext context) {
    final searchRow = Row(
      children: [
        Expanded(
          child: SearchAnchor(
            searchController: searchController,
            builder: (context, controller) => SearchBar(
              controller: controller,
              padding: const WidgetStatePropertyAll<EdgeInsets>(EdgeInsets.symmetric(horizontal: 16.0)),
              leading: const Icon(Icons.search),
              hintText: 'Buscar producto por nombre o código...',
              onTap: () => controller.openView(),
              onChanged: (_) => controller.openView(),
            ),
            suggestionsBuilder: (context, controller) async {
              final results = await ProductRepository.instance.searchProducts(controller.text.trim());
              return results.map((product) => ListTile(
                title: Text(product.name),
                subtitle: Text('Código: ${product.code} | Stock: ${product.stock}'),
                trailing: Text('\$${product.price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () => onAddProductToCart(product.toMap()),
              )).toList();
            },
          ),
        ),
        const SizedBox(width: 8),
        // Botón de escáner de código de barras con la cámara, pensado
        // sobre todo para el uso en teléfono.
        Material(
          color: const Color(0xFF232D37),
          borderRadius: BorderRadius.circular(12),
          child: IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
            tooltip: 'Escanear código de barras',
            onPressed: onScanBarcode,
          ),
        ),
      ],
    );

    final cartCard = Card(
      color: Colors.white,
      elevation: 2,
      child: cart.isEmpty
          ? const Center(
              heightFactor: 4,
              child: Text('El carrito está vacío.', style: TextStyle(fontSize: 16, color: Colors.grey)),
            )
          : ListView.builder(
              shrinkWrap: !expandCart,
              physics: expandCart ? null : const NeverScrollableScrollPhysics(),
              itemCount: cart.length,
              itemBuilder: (context, index) {
                final item = cart[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF232D37),
                    child: Text('${item['quantity']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(item['name'].toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Código: ${item['code']} | unit: \$${item['price']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('\$${((item['price'] ?? 0.0) * item['quantity']).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                        onPressed: () => onDecreaseQuantity(index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                        onPressed: () => onIncreaseQuantity(index),
                      ),
                    ],
                  ),
                );
              },
            ),
    );

    if (expandCart) {
      // Layout ancho (escritorio/tablet): la lista de carrito ocupa todo el
      // espacio vertical disponible dentro de su columna.
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            searchRow,
            const SizedBox(height: 15),
            Expanded(child: cartCard),
          ],
        ),
      );
    }

    // Layout angosto (teléfono): el carrito tiene una altura máxima fija y es
    // scrolleable dentro de sí mismo, para no competir por espacio con el
    // panel de cobro que va justo debajo.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          searchRow,
          const SizedBox(height: 15),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: cartCard,
          ),
        ],
      ),
    );
  }
}