import 'package:flutter/material.dart';
import '../models/database_helper.dart';
import 'sales_terminal_screen.dart'; // Importación necesaria para la navegación

class InventoryScreen extends StatefulWidget {
  final String userRole; 

  const InventoryScreen({Key? key, required this.userRole}) : super(key: key);

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;

  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshInventory();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _refreshInventory() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getProducts();
    if (!mounted) return;
    setState(() {
      _products = data;
      _isLoading = false;
    });

    // CORREGIDO: si getProducts() no pudo sincronizar (red lenta/caída),
    // avisamos aquí en vez de dejarlo silencioso.
    if (!DatabaseHelper.instance.lastSyncOk && mounted) {
      _showSnackBar('⚠️ No se pudo conectar con Supabase. Mostrando datos guardados en este equipo.', Colors.orange);
    }
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

              // CORREGIDO: si el código ya existe localmente, avisamos antes
              // de intentar guardar, en vez de dejar que Supabase truene por
              // llave duplicada sin explicación clara para el usuario.
              final code = _codeController.text.trim();
              final yaExiste = _products.any((p) => p['code'].toString() == code);
              if (yaExiste) {
                Navigator.pop(context);
                _showSnackBar('❌ Ese código ya existe. Usa "Editar" en el producto o elige un código distinto.', Colors.red);
                return;
              }
              
              final newProduct = {
                'code': code,
                'name': _nameController.text.trim(),
                'price': double.tryParse(_priceController.text) ?? 0.0,
                'stock': int.tryParse(_stockController.text) ?? 0,
              };

              try {
                Navigator.pop(context);
                await DatabaseHelper.instance.insertProduct(newProduct);
                if (DatabaseHelper.instance.lastSyncOk) {
                  _showSnackBar('¡Producto guardado y sincronizado con Supabase!', Colors.green);
                } else {
                  _showSnackBar('⚠️ Guardado solo en este equipo: no se pudo sincronizar con Supabase (revisa tu conexión).', Colors.orange);
                }
              } catch (e) {
                _showSnackBar('❌ Error al guardar: $e', Colors.red);
              }
              
              if (!mounted) return;
              _refreshInventory();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> product) {
    if (widget.userRole != 'Administrador' && widget.userRole != 'admin') {
      _showSnackBar('⚠️ Acceso denegado: Solo los Administradores pueden editar productos.', Colors.red);
      return;
    }

    final nameEdit = TextEditingController(text: product['name'].toString());
    final priceEdit = TextEditingController(text: product['price'].toString());
    final stockEdit = TextEditingController(text: product['stock'].toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar ${product['name']}'),
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
              final updatedProduct = {
                'code': product['code'].toString(), 
                'name': nameEdit.text.trim(),
                'price': double.tryParse(priceEdit.text) ?? product['price'],
                'stock': int.tryParse(stockEdit.text) ?? product['stock'],
              };
              
              try {
                Navigator.pop(context);
                await DatabaseHelper.instance.updateProduct(updatedProduct);
                if (DatabaseHelper.instance.lastSyncOk) {
                  _showSnackBar('¡Producto actualizado y sincronizado con Supabase!', Colors.green);
                } else {
                  _showSnackBar('⚠️ Actualizado solo en este equipo: no se pudo sincronizar con Supabase.', Colors.orange);
                }
              } catch (e) {
                _showSnackBar('❌ Error al actualizar: $e', Colors.red);
              }
              
              if (!mounted) return;
              _refreshInventory();
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
                Navigator.pop(context);
                await DatabaseHelper.instance.deleteProduct(code);
                if (DatabaseHelper.instance.lastSyncOk) {
                  _showSnackBar('Producto eliminado con éxito (local y Supabase).', Colors.blue);
                } else {
                  _showSnackBar('⚠️ Eliminado solo en este equipo: no se pudo sincronizar con Supabase.', Colors.orange);
                }
              } catch (e) {
                _showSnackBar('❌ Error al eliminar: $e', Colors.red);
              }
              
              if (!mounted) return;
              _refreshInventory();
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Control de Inventario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2C3E50),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Actualizar / reintentar sincronización',
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshInventory,
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SalesTerminalScreen(userRole: widget.userRole),
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
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _products.isEmpty
                      ? const Center(child: Text('No hay productos registrados.'))
                      : ListView.builder(
                          itemCount: _products.length,
                          itemBuilder: (context, index) {
                            final product = _products[index];
                            final double price = ((product['price'] ?? 0.0) as num).toDouble();
                            
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
                                  product['name']?.toString() ?? 'Sin nombre',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                subtitle: Text(
                                  'Código: ${product['code']}\nStock: ${product['stock']}',
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
                                        onPressed: () => _confirmDelete(product['code'].toString()),
                                      ),
                                    ]
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}