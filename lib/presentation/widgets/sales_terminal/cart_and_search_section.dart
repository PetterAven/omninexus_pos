import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../domain/entities/product.dart';
import '../../providers/cart_controller.dart';

class CartAndSearchSection extends ConsumerStatefulWidget {
  final bool expandCart;
  final TextEditingController searchController;
  final VoidCallback onScanBarcode;

  const CartAndSearchSection({
    super.key,
    required this.expandCart,
    required this.searchController,
    required this.onScanBarcode,
  });

  @override
  ConsumerState<CartAndSearchSection> createState() =>
      _CartAndSearchSectionState();
}

class _CartAndSearchSectionState extends ConsumerState<CartAndSearchSection> {
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  List<Product> _searchResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() async {
    final query = widget.searchController.text.trim();

    if (query.isEmpty) {
      _hideOverlay();
      if (mounted) {
        setState(() {
          _searchResults = [];
        });
      }
      return;
    }

    final results = await ProductRepository.instance.searchProducts(query);

    if (!mounted) return;

    // Si coincide exactamente con el código de barras al escanear rápido
    final exactMatch = results.where((p) => p.code == query).firstOrNull;
    if (exactMatch != null) {
      _hideOverlay();
      widget.searchController.clear();
      _focusNode.unfocus();
      await _addProductToCart(exactMatch);
      return;
    }

    setState(() {
      _searchResults = results;
      _isLoading = false;
    });

    _showOverlay();
  }

  /// Procesa la adición de productos al carrito (por pieza o con popup para granel)
  Future<void> _addProductToCart(Product product) async {
    double quantity = 1.0;

    // Si el producto está registrado a granel, se abre el diálogo de cantidad
    if (product.isWeighted) {
      final double? enteredQuantity =
          await _showBulkQuantityDialog(context, product);

      // Si el usuario cancela o deja vacío, se aborta la acción
      if (enteredQuantity == null || enteredQuantity <= 0) {
        return;
      }
      quantity = enteredQuantity;
    }

    // Llamada corregida usando el parámetro nombrado 'quantity'
    final result = ref.read(cartControllerProvider.notifier).addProduct(
          product,
          quantity: quantity,
        );

    if (!mounted) return;

    if (result == CartOperationResult.outOfStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sin stock suficiente para ${product.name}'),
          backgroundColor: Colors.red,
        ),
      );
    } else if (result == CartOperationResult.invalidWeight) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cantidad o peso no válido'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  /// Pop-up emergente para ingresar la cantidad exacta (kilos, litros, gramos, etc.)
  Future<double?> _showBulkQuantityDialog(
      BuildContext context, Product product,
      {double? initialValue}) async {
    final controller =
        TextEditingController(text: initialValue?.toString() ?? '');
    final unitLabel = product.unit.isNotEmpty ? product.unit : 'kg';

    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.scale, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Venta a granel: ${product.name}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Precio por $unitLabel: \$${product.price.toStringAsFixed(2)}',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Ingresa la cantidad ($unitLabel)',
                hintText: 'Ej. 0.250 o 1.5',
                suffixText: unitLabel,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onSubmitted: (value) {
                final val = double.tryParse(value);
                Navigator.pop(dialogCtx, val);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, null),
            child:
                const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              final val = double.tryParse(controller.text);
              Navigator.pop(dialogCtx, val);
            },
            child: const Text('Agregar al Carrito'),
          ),
        ],
      ),
    );
  }

  void _showOverlay() {
    _hideOverlay();

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width - 32,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0.0, 52.0),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context).colorScheme.surface,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 300),
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _searchResults.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('Sin resultados.'),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: _searchResults.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final product = _searchResults[index];
                              return InkWell(
                                onTap: () {
                                  _hideOverlay();
                                  widget.searchController.clear();
                                  _focusNode.unfocus();
                                  _addProductToCart(product);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                    vertical: 12.0,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  product.name,
                                                  style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                if (product.isWeighted) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.orange[100],
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(4),
                                                    ),
                                                    child: Text(
                                                      'Granel (${product.unit})',
                                                      style: TextStyle(
                                                        color:
                                                            Colors.orange[900],
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ]
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Cód: ${product.code} | Stock: ${product.stock} ${product.unit}',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '\$${product.price.toStringAsFixed(2)} / ${product.unit}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _hideOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartControllerProvider);

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Campo de búsqueda con Overlay
          CompositedTransformTarget(
            link: _layerLink,
            child: TextField(
              controller: widget.searchController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Buscar producto por nombre o código...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          widget.searchController.clear();
                          _hideOverlay();
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      tooltip: 'Escanear código de barras',
                      onPressed: widget.onScanBarcode,
                    ),
                  ],
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Renderizado de ítems en el carrito
          Expanded(
            flex: widget.expandCart ? 1 : 0,
            child: cartItems.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32.0),
                      child: Text(
                        'El carrito está vacío.',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: !widget.expandCart,
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      final unitLabel = item.product.unit.isNotEmpty
                          ? item.product.unit
                          : 'pza';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8.0),
                        child: ListTile(
                          title: Text(item.product.name),
                          subtitle: Text(
                            item.product.isWeighted
                                ? '${item.quantity.toStringAsFixed(3)} $unitLabel x \$${item.product.price.toStringAsFixed(2)}'
                                : '${item.quantity.toInt()} $unitLabel x \$${item.product.price.toStringAsFixed(2)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Producto a granel: no tiene sentido picarle "+" de 1 en 1 kg,
                              // así que aquí se reabre el diálogo de peso para editarlo.
                              if (item.product.isWeighted)
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue, size: 20),
                                  tooltip: 'Editar cantidad',
                                  onPressed: () async {
                                    final nuevaCantidad =
                                        await _showBulkQuantityDialog(
                                      context,
                                      item.product,
                                      initialValue: item.quantity,
                                    );
                                    if (nuevaCantidad != null &&
                                        nuevaCantidad > 0) {
                                      ref
                                          .read(
                                              cartControllerProvider.notifier)
                                          .updateQuantity(
                                              index, nuevaCantidad);
                                    }
                                  },
                                )
                              else ...[
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline,
                                      color: Colors.redAccent, size: 22),
                                  onPressed: () {
                                    ref
                                        .read(cartControllerProvider.notifier)
                                        .decreaseQuantity(index);
                                  },
                                ),
                                Text(
                                  item.quantity.toInt().toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline,
                                      color: Colors.green, size: 22),
                                  onPressed: () {
                                    final result = ref
                                        .read(cartControllerProvider.notifier)
                                        .increaseQuantity(index);
                                    if (result ==
                                        CartOperationResult.noMoreStock) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Sin más stock disponible de ${item.product.name}'),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                              const SizedBox(width: 8),
                              Text(
                                '\$${item.subtotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  ref
                                      .read(cartControllerProvider.notifier)
                                      .removeItem(index);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}