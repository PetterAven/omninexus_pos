import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../domain/entities/product.dart';
import '../../providers/cart_controller.dart';

/// Sección de "buscador de productos + carrito" de la Terminal de
/// Ventas. Se usa tanto en el layout ancho (PC/tablet) como en el
/// angosto (teléfono) -- por eso el parámetro [expandCart].
///
/// CORREGIDO: convertido a ConsumerWidget. Antes recibía `cart` (ya
/// convertido a `List<Map>` por el padre) y tres callbacks
/// (`onAddProductToCart`, `onIncreaseQuantity`, `onDecreaseQuantity`)
/// para que SalesTerminalScreen mutara su `_cart` local. Como el
/// carrito ahora vive en cartControllerProvider, este widget lee/muta
/// el estado directo -- ya no hay nada que "subir" al padre para eso.
/// Solo sobrevive `onScanBarcode` como callback porque no es una simple
/// mutación de carrito: navega a otra pantalla y además sincroniza el
/// código escaneado con el otro dispositivo vía SyncRepository, algo
/// que sigue siendo responsabilidad de SalesTerminalScreen.
class CartAndSearchSection extends ConsumerWidget {
  final bool expandCart;
  final SearchController searchController;
  final VoidCallback onScanBarcode;

  const CartAndSearchSection({
    super.key,
    required this.expandCart,
    required this.searchController,
    required this.onScanBarcode,
  });

  void _handleAddProduct(BuildContext context, WidgetRef ref, Product product) {
    final result = ref.read(cartControllerProvider.notifier).addProduct(product);
    if (result == CartOperationResult.success) {
      searchController.clear();
      return;
    }
    _showStockSnackBar(context, result);
  }

  void _handleIncreaseQuantity(BuildContext context, WidgetRef ref, int index) {
    final result = ref.read(cartControllerProvider.notifier).increaseQuantity(index);
    _showStockSnackBar(context, result);
  }

  void _showStockSnackBar(BuildContext context, CartOperationResult result) {
    final message = switch (result) {
      CartOperationResult.outOfStock => 'Este producto no tiene stock disponible.',
      CartOperationResult.noMoreStock => 'No hay más stock disponible.',
      CartOperationResult.success => null,
    };
    if (message == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);

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
                onTap: () => _handleAddProduct(context, ref, product),
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
                    child: Text('${item.quantity}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(item.product.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Código: ${item.product.code} | unit: \$${item.product.price}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('\$${item.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                        onPressed: () => ref.read(cartControllerProvider.notifier).decreaseQuantity(index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                        onPressed: () => _handleIncreaseQuantity(context, ref, index),
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