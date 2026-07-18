import 'package:flutter/material.dart';
import '../models/database_helper.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Map<String, dynamic>> _products = [];

  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _loadInventory() async {
    final data = await DatabaseHelper.instance.getProducts();
    setState(() {
      _products = data;
    });
  }

  void _showAddProductDialog() {
    _codeController.clear();
    _nameController.clear();
    _priceController.clear();
    _stockController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Agregar Nuevo Producto', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF232D37))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'Código de Barras / Único', prefixIcon: Icon(Icons.qr_code)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre del Producto', prefixIcon: Icon(Icons.shopping_bag)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Precio de Venta (\$)', prefixIcon: Icon(Icons.attach_money)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cantidad en Stock Inicial', prefixIcon: Icon(Icons.unarchive)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF232D37)),
            onPressed: () async {
              if (_codeController.text.isEmpty || _nameController.text.isEmpty || _priceController.text.isEmpty || _stockController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Por favor, rellena todos los campos.'))
                );
                return;
              }

              try {
                final db = await DatabaseHelper.instance.database;
                await db.insert('products', {
                  'code': _codeController.text.trim(),
                  'name': _nameController.text.trim(),
                  'price': double.parse(_priceController.text.trim()),
                  'stock': int.parse(_stockController.text.trim()),
                });

                if (mounted) {
                  Navigator.pop(context);
                  _loadInventory();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Producto guardado exitosamente.'))
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al guardar en la base de datos: $e'))
                  );
                }
              }
            },
            child: const Text('Guardar Producto', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Control de Inventario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF232D37),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Productos en Existencia', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF232D37))),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF232D37), foregroundColor: Colors.white),
                  onPressed: _showAddProductDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo Producto'),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Expanded(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: _products.isEmpty
                    ? const Center(child: Text('No hay productos registrados.'))
                    : ListView.separated(
                        itemCount: _products.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final p = _products[index];
                          final int stock = p['stock'] ?? 0;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF232D37).withOpacity(0.1),
                              child: const Icon(Icons.inventory_2, color: Color(0xFF232D37)),
                            ),
                            title: Text(p['name'] ?? 'Sin nombre', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Código: ${p['code'] ?? 'N/A'}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('\$${(p['price'] ?? 0.0).toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(width: 30),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: stock < 5 ? Colors.red[50] : Colors.green[50],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Stock: $stock',
                                    style: TextStyle(color: stock < 5 ? Colors.red[700] : Colors.green[700], fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}