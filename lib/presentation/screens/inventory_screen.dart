import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/product.dart';
import '../providers/product_controller.dart';
import '../widgets/dialogs/add_product_dialog.dart';
import '../widgets/inventory/import_export_dialog.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  final String? userRole;

  const InventoryScreen({
    super.key,
    this.userRole,
  });

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productState = ref.watch(productControllerProvider);
    final isPageAdmin = widget.userRole == 'Administrador';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario de Productos'),
        centerTitle: true,
        actions: [
          // Botón para Importar / Exportar Productos
          productState.maybeWhen(
            data: (products) => IconButton(
              icon: const Icon(Icons.import_export),
              tooltip: 'Importar / Exportar',
              onPressed: () => showImportExportDialog(context, ref, products),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF232D37),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nuevo Producto', style: TextStyle(color: Colors.white)),
        onPressed: () => showAddProductDialog(context, ref),
      ),
      body: Column(
        children: [
          // Campo de Búsqueda
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase().trim();
                });
              },
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o código...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // Lista de Productos
          Expanded(
            child: productState.when(
              loading: () => const ProductSkeletonLoader(),
              error: (error, stack) => Center(
                child: Text(
                  'Error al cargar productos: $error',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              data: (products) {
                final filteredProducts = products.where((p) {
                  final nameMatches = p.name.toLowerCase().contains(_searchQuery);
                  final codeMatches = p.code.toLowerCase().contains(_searchQuery);
                  return nameMatches || codeMatches;
                }).toList();

                if (filteredProducts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isEmpty ? Icons.inventory_2_outlined : Icons.search_off,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No hay productos registrados'
                              : 'No se encontraron resultados para "$_searchQuery"',
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredProducts.length,
                  padding: const EdgeInsets.only(bottom: 80),
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return _ProductCard(
                      product: product,
                      isAdmin: isPageAdmin,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ProductSkeletonLoader extends StatefulWidget {
  const ProductSkeletonLoader({super.key});

  @override
  State<ProductSkeletonLoader> createState() => _ProductSkeletonLoaderState();
}

class _ProductSkeletonLoaderState extends State<ProductSkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = 0.3 + (_controller.value * 0.4);
        return ListView.builder(
          itemCount: 6,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemBuilder: (context, index) {
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: opacity),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: opacity),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 120,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: opacity * 0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 60,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: opacity),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final Product product;
  final bool isAdmin;

  const _ProductCard({
    required this.product,
    this.isAdmin = true,
  });

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar producto?'),
        content: Text('¿Estás seguro de que deseas eliminar "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              ref.read(productControllerProvider.notifier).deleteProduct(product.code);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Producto "${product.name}" eliminado.')),
              );
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // v1.1.0: product.stock es double. Piezas se ven como "5", productos
    // a granel se ven con 2 decimales ("3.50 kg") en vez de "5.0"/"3.5 kg".
    final stockLabel = product.isWeighted
        ? '${product.stock.toStringAsFixed(2)} ${product.unit}'
        : '${product.stock.toStringAsFixed(0)} pzas';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: product.isWeighted ? Colors.amber.shade100 : Colors.blue.shade100,
          child: Icon(
            product.isWeighted ? Icons.scale : Icons.inventory_2,
            color: product.isWeighted ? Colors.amber.shade900 : Colors.blue.shade900,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                product.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (product.isWeighted) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.amber.shade800),
                ),
                child: Text(
                  '⚖️ ${product.unit}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.amber.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            'Código: ${product.code}\nStock: $stockLabel',
            style: TextStyle(color: Colors.grey.shade700, height: 1.3),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\$${product.price.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              tooltip: 'Editar',
              onPressed: () => showAddProductDialog(context, ref, productToEdit: product),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Eliminar',
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}