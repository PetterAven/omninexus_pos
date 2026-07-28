import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/sync_status.dart';
import '../../domain/entities/product.dart';
import '../providers/product_controller.dart';
import 'sales_terminal_screen.dart'; // Importación necesaria para la navegación

class InventoryScreen extends ConsumerStatefulWidget {
  final String userRole;

  const InventoryScreen({super.key, required this.userRole});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showAddProductDialog() {
    if (widget.userRole != 'Administrador' && widget.userRole != 'admin') {
      _showSnackBar('⚠️ Acceso denegado: Solo los Administradores pueden registrar productos.', Colors.red);
      return;
    }

    _codeController.clear();
    _nameController.clear();
    _priceController.clear();
    _stockController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir Nuevo Producto'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'Código de Barras'),
              ),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre del Producto'),
              ),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Precio'),
              ),
              TextField(
                controller: _stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stock Inicial'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_codeController.text.isEmpty || _nameController.text.isEmpty) return;

              final newProduct = Product(
                code: _codeController.text.trim(),
                name: _nameController.text.trim(),
                price: double.tryParse(_priceController.text) ?? 0.0,
                stock: int.tryParse(_stockController.text) ?? 0,
              );

              try {
                final result = await ref.read(productControllerProvider.notifier).addProduct(newProduct);
                if (!context.mounted) return;
                Navigator.pop(context);

                switch (result) {
                  case ProductSaveResult.duplicateCode:
                    _showSnackBar(
                      '❌ Ese código ya existe. Usa "Editar" en el producto o elige un código distinto.',
                      Colors.red,
                    );
                    break;
                  case ProductSaveResult.success:
                    _showSnackBar(
                      SyncStatus.lastSyncOk
                          ? '¡Producto guardado y sincronizado con Supabase!'
                          : '⚠️ Guardado solo en este equipo: no se pudo sincronizar con Supabase (revisa tu conexión).',
                      SyncStatus.lastSyncOk ? Colors.green : Colors.orange,
                    );
                    break;
                }
              } catch (e) {
                if (!context.mounted) return;
                Navigator.pop(context);
                _showSnackBar('❌ Error al guardar: $e', Colors.red);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(Product product) {
    if (widget.userRole != 'Administrador' && widget.userRole != 'admin') {
      _showSnackBar('⚠️ Acceso denegado: Solo los Administradores pueden editar productos.', Colors.red);
      return;
    }

    final nameEdit = TextEditingController(text: product.name);
    final priceEdit = TextEditingController(text: product.price.toString());
    final stockEdit = TextEditingController(text: product.stock.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameEdit,
              decoration: const InputDecoration(labelText: 'Nombre del Producto'),
            ),
            TextField(
              controller: priceEdit,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Precio'),
            ),
            TextField(
              controller: stockEdit,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Stock en Existencia'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedProduct = Product(
                code: product.code,
                name: nameEdit.text.trim(),
                price: double.tryParse(priceEdit.text) ?? product.price,
                stock: int.tryParse(stockEdit.text) ?? product.stock,
              );

              try {
                await ref.read(productControllerProvider.notifier).updateProduct(updatedProduct);
                if (!context.mounted) return;
                Navigator.pop(context);
                _showSnackBar(
                  SyncStatus.lastSyncOk
                      ? '¡Producto actualizado y sincronizado con Supabase!'
                      : '⚠️ Actualizado solo en este equipo: no se pudo sincronizar con Supabase.',
                  SyncStatus.lastSyncOk ? Colors.green : Colors.orange,
                );
              } catch (e) {
                if (!context.mounted) return;
                Navigator.pop(context);
                _showSnackBar('❌ Error al actualizar: $e', Colors.red);
              }
            },
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String code) {
    if (widget.userRole != 'Administrador' && widget.userRole != 'admin') {
      _showSnackBar('⚠️ Acceso denegado: Solo los Administradores pueden eliminar productos.', Colors.red);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar producto?'),
        content: const Text('Esta acción quitará el producto del inventario local y de Supabase.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await ref.read(productControllerProvider.notifier).deleteProduct(code);
                if (!context.mounted) return;
                Navigator.pop(context);
                _showSnackBar(
                  SyncStatus.lastSyncOk
                      ? 'Producto eliminado con éxito (local y Supabase).'
                      : '⚠️ Eliminado solo en este equipo: no se pudo sincronizar con Supabase.',
                  SyncStatus.lastSyncOk ? Colors.blue : Colors.orange,
                );
              } catch (e) {
                if (!context.mounted) return;
                Navigator.pop(context);
                _showSnackBar('❌ Error al eliminar: $e', Colors.red);
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productControllerProvider);

    // CORREGIDO (Sprint 4, Paso 2): antes esto escuchaba
    // productControllerProvider y revisaba el flag estático
    // SyncStatus.lastSyncOk a mano cada vez que terminaba en AsyncData.
    // Ahora syncStatusProvider es reactivo de verdad, así que se escucha
    // directo -- se dispara solo cuando de verdad cambia (true -> false),
    // sin acoplarse al ciclo de vida de otro provider.
    ref.listen<bool>(syncStatusProvider, (previous, next) {
      if (next == false) {
        _showSnackBar(
          '⚠️ No se pudo conectar con Supabase. Mostrando datos guardados en este equipo.',
          Colors.orange,
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Control de Inventario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2C3E50),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Actualizar / reintentar sincronización',
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => ref.read(productControllerProvider.notifier).refresh(),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SalesTerminalScreen(),
                ),
              );
            },
            icon: const Icon(Icons.point_of_sale, color: Colors.greenAccent),
            label: const Text('Terminal de Ventas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 15),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Productos en Existencia',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                ),
                if (widget.userRole == 'Administrador' || widget.userRole == 'admin')
                  ElevatedButton.icon(
                    onPressed: _showAddProductDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Nuevo Producto'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C3E50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: productsAsync.when(
                data: (products) => products.isEmpty
                    ? const Center(child: Text('No hay productos registrados.'))
                    : ListView.builder(
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          final double price = product.price;

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F3F4),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.archive, color: Color(0xFF2C3E50)),
                              ),
                              title: Text(
                                product.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              subtitle: Text(
                                'Código: ${product.code}\nStock: ${product.stock}',
                                style: const TextStyle(height: 1.3),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '\$${price.toStringAsFixed(2)}',
                                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(width: 12),
                                  if (widget.userRole == 'Administrador' || widget.userRole == 'admin') ...[
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _showEditDialog(product),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _confirmDelete(product.code),
                                    ),
                                  ]
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error al cargar productos: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}