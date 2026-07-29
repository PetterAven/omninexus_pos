import 'package:flutter/material.dart';
import 'package:omninexus_pos/domain/entities/product.dart';

class AdaptableProductSearch extends StatefulWidget {
  final List<Product> products;
  final Function(Product) onProductSelected;

  const AdaptableProductSearch({
    super.key,
    required this.products,
    required this.onProductSelected,
  });

  @override
  State<AdaptableProductSearch> createState() => _AdaptableProductSearchState();
}

class _AdaptableProductSearchState extends State<AdaptableProductSearch> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  List<Product> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSearchChanged);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _hideOverlay();
      }
    });
  }

  void _onSearchChanged() {
    final query = _controller.text.trim();

    // 1. Si NO hay texto escrito, NO se muestra NADA abajo (sin recuadro gris)
    if (query.isEmpty) {
      _hideOverlay();
      return;
    }

    // 2. Filtrar lista de productos por nombre o código
    setState(() {
      _filteredProducts = widget.products.where((p) {
        final nameMatch = p.name.toLowerCase().contains(query.toLowerCase());
        final codeMatch = p.code.toLowerCase().contains(query.toLowerCase());
        return nameMatch || codeMatch;
      }).toList();
    });

    // 3. Desplegar el menú si hay coincidencias
    if (_filteredProducts.isNotEmpty) {
      _showOverlay();
    } else {
      _hideOverlay();
    }
  }

  void _showOverlay() {
    _hideOverlay(); // Limpiar si ya había uno abierto

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0.0, size.height + 6.0),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  shrinkWrap: true, // CLAVE: Se encoge y ajusta al número de ítems (ej. 1, 2 o 3)
                  itemCount: _filteredProducts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    final product = _filteredProducts[index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        product.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('Cód: ${product.code} | Stock: ${product.stock}'),
                      trailing: Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      onTap: () {
                        widget.onProductSelected(product);
                        _controller.clear();
                        _focusNode.unfocus();
                        _hideOverlay();
                      },
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
    _controller.dispose();
    _focusNode.dispose();
    _hideOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          hintText: 'Buscar producto por nombre o código...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                    _hideOverlay();
                  },
                )
              : null,
          filled: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}