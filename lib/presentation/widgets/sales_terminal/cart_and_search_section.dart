import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omninexus_pos/domain/entities/product.dart';
import 'package:omninexus_pos/data/repositories/product_repository.dart';
import 'package:omninexus_pos/presentation/providers/cart_controller.dart';

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
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _hideOverlay();
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _hideOverlay();
    _focusNode.dispose();
    super.dispose();
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      _hideOverlay();
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _isLoading = true);

      try {
        final results = await ProductRepository.instance.searchProducts(query);

        Product? exactMatch;
        for (final product in results) {
          if (product.code == query.trim()) {
            exactMatch = product;
            break;
          }
        }

        if (exactMatch != null) {
          _hideOverlay();
          widget.searchController.clear();
          _focusNode.unfocus();
          await _addProductToCart(exactMatch);
          return;
        }

        _searchResults = results;
        if (_focusNode.hasFocus && _searchResults.isNotEmpty) {
          _showOverlay();
        } else {
          _hideOverlay();
        }
      } catch (e) {
        debugPrint('Error en la búsqueda: $e');
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    });
  }

  void _showOverlay() {
    _hideOverlay();

    if (_searchResults.isEmpty) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width - 32,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 60),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 280),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final product = _searchResults[index];
                  final stockText = product.isWeighted
                      ? product.stock.toStringAsFixed(3)
                      : product.stock.toInt().toString();

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) {
                      _hideOverlay();
                      widget.searchController.clear();
                      _focusNode.unfocus();
                      _addProductToCart(product);
                    },
                    child: ListTile(
                      dense: true,
                      title: Text(
                        product.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                          'Código: ${product.code} | Stock: $stockText ${product.unit}'),
                      trailing: Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Future<void> _addProductToCart(Product product) async {
    double? quantity;

    if (product.isWeighted) {
      quantity = await _showBulkQuantityDialog(context, product);
      if (quantity == null || quantity <= 0) return;
    }

    final result = ref.read(cartControllerProvider.notifier).addProduct(
          product,
          weight: product.isWeighted ? quantity : null,
        );

    if (!mounted) return;

    _showResultSnackBar(result, product.name);
  }

  void _showResultSnackBar(CartOperationResult result, String productName) {
    switch (result) {
      case CartOperationResult.success:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $productName actualizado'),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 1),
          ),
        );
        break;
      case CartOperationResult.outOfStock:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Este producto no tiene stock disponible.'),
            backgroundColor: Colors.red,
          ),
        );
        break;
      case CartOperationResult.noMoreStock:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay más stock disponible para este producto.'),
            backgroundColor: Colors.orange,
          ),
        );
        break;
      case CartOperationResult.invalidWeight:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El peso o cantidad ingresada no es válida.'),
            backgroundColor: Colors.orange,
          ),
        );
        break;
      case CartOperationResult.notApplicableForWeighted:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Este producto se vende por peso. Ajusta la cantidad correctamente.'),
            backgroundColor: Colors.orange,
          ),
        );
        break;
    }
  }

  Future<double?> _showBulkQuantityDialog(
      BuildContext context, Product product, {double? initialQuantity}) async {
    final controller = TextEditingController(
      text: initialQuantity != null ? initialQuantity.toStringAsFixed(3) : '',
    );
    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ingresar cantidad/peso (${product.unit})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Producto: ${product.name}'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Cantidad o peso en ${product.unit}',
                hintText: 'Ej: 0.500 o 1.250',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final val =
                  double.tryParse(controller.text.replaceAll(',', '.'));
              Navigator.pop(context, val);
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartControllerProvider);

    final Widget cartListWidget = cartItems.isEmpty
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_cart_outlined,
                    size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Text(
                  'El carrito está vacío',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          )
        : ListView.separated(
            itemCount: cartItems.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = cartItems[index];
              final isWeighted = item.product.isWeighted;

              final qtyDisplay = isWeighted
                  ? item.quantity.toStringAsFixed(3)
                  : item.quantity.toInt().toString();

              final double itemTotal = item.quantity * item.product.price;

              return ListTile(
                title: Text(
                  item.product.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '\$${item.product.price.toStringAsFixed(2)} c/u | Total: \$${itemTotal.toStringAsFixed(2)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- BOTÓN DISMINUIR (-) ---
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.orange),
                      onPressed: () async {
                        if (isWeighted) {
                          final newQty = await _showBulkQuantityDialog(
                            context,
                            item.product,
                            initialQuantity: item.quantity,
                          );
                          if (newQty != null) {
                            if (newQty <= 0) {
                              ref
                                  .read(cartControllerProvider.notifier)
                                  .removeItem(index);
                            } else {
                              ref
                                  .read(cartControllerProvider.notifier)
                                  .updateQuantity(index, newQty);
                            }
                          }
                        } else {
                          if (item.quantity > 1) {
                            ref
                                .read(cartControllerProvider.notifier)
                                .updateQuantity(index, item.quantity - 1);
                          } else {
                            ref
                                .read(cartControllerProvider.notifier)
                                .removeItem(index);
                          }
                        }
                      },
                    ),

                    // --- CANTIDAD ACTUAL ---
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$qtyDisplay ${item.product.unit}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),

                    // --- BOTÓN AUMENTAR (+) ---
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline,
                          color: Colors.green),
                      onPressed: () async {
                        if (isWeighted) {
                          final newQty = await _showBulkQuantityDialog(
                            context,
                            item.product,
                            initialQuantity: item.quantity,
                          );
                          if (newQty != null && newQty > 0) {
                            ref
                                .read(cartControllerProvider.notifier)
                                .updateQuantity(index, newQty);
                          }
                        } else {
                          final result = ref
                              .read(cartControllerProvider.notifier)
                              .addProduct(item.product);
                          _showResultSnackBar(result, item.product.name);
                        }
                      },
                    ),

                    const SizedBox(width: 4),

                    // --- BOTÓN ELIMINAR ---
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        ref
                            .read(cartControllerProvider.notifier)
                            .removeItem(index);
                      },
                    ),
                  ],
                ),
              );
            },
          );

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          CompositedTransformTarget(
            link: _layerLink,
            child: TextField(
              controller: widget.searchController,
              focusNode: _focusNode,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Buscar producto por nombre o código...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: widget.onScanBarcode,
                      tooltip: 'Escanear código de barras',
                    ),
                  ],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          widget.expandCart
              ? Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: cartListWidget,
                  ),
                )
              : Container(
                  height: 350,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: cartListWidget,
                ),
        ],
      ),
    );
  }
}