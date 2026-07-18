import 'package:flutter/material.dart';
import '../models/database_helper.dart';

class AdminScreen extends StatefulWidget {
  final String userRole;

  const AdminScreen({Key? key, required this.userRole}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshProducts();
  }

  Future<void> _refreshProducts() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getProducts();
    setState(() {
      _products = data;
      _isLoading = false;
    });
  }

  Future<void> _addProduct(String code, String name, double price, int stock, String imageUrl) async {
    final db = await DatabaseHelper.instance.database;
    try {
      await db.insert('products', {
        'code': code,
        'name': name,
        'price': price,
        'stock': stock,
        'imageUrl': imageUrl.isEmpty ? 'https://via.placeholder.com/150' : imageUrl,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Producto registrado con éxito'), backgroundColor: Colors.green),
      );
      _refreshProducts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Error: El código de barras ya existe'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _updateProduct(int id, String code, String name, double price, int stock, String imageUrl) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'products',
      {
        'code': code,
        'name': name,
        'price': price,
        'stock': stock,
        'imageUrl': imageUrl,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🔄 Producto actualizado')));
    _refreshProducts();
  }

  Future<void> _deleteProduct(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🗑️ Producto eliminado'), backgroundColor: Colors.redAccent));
    _refreshProducts();
  }

  void _showForm(Map<String, dynamic>? product) {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final stockController = TextEditingController();
    final imageController = TextEditingController();

    if (product != null) {
      codeController.text = product['code'];
      nameController.text = product['name'];
      priceController.text = product['price'].toString();
      stockController.text = product['stock'].toString();
      imageController.text = product['imageUrl'];
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(product == null ? '📦 Agregar Nuevo Producto' : '✏️ Editar Producto'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: const InputDecoration(labelText: 'Código de Barras / Único'),
                enabled: product == null,
              ),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre del Producto')),
              TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Precio (\$ MXN)'), keyboardType: TextInputType.number),
              TextField(controller: stockController, decoration: const InputDecoration(labelText: 'Cantidad en Stock'), keyboardType: TextInputType.number),
              TextField(controller: imageController, decoration: const InputDecoration(labelText: 'URL de la Imagen (Opcional)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim();
              final name = nameController.text.trim();
              final price = double.tryParse(priceController.text) ?? 0.0;
              final stock = int.tryParse(stockController.text) ?? 0;
              final img = imageController.text.trim();

              if (code.isEmpty || name.isEmpty || price <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Llena los campos obligatorios')));
                return;
              }

              Navigator.pop(context);

              if (product == null) {
                await _addProduct(code, name, price, stock, img);
              } else {
                await _updateProduct(product['id'], code, name, price, stock, img);
              }
            },
            child: Text(product == null ? 'Guardar' : 'Actualizar'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool esAdmin = widget.userRole == 'Administrador';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Inventario y Precios', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo[900],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? const Center(child: Text('No hay productos registrados en el sistema.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final p = _products[index];
                    final String imageUrl = p['imageUrl'] ?? '';

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        // 🟢 CORREGIDO: Uso seguro de imágenes en listas nativas con manejo de errores correcto
                        leading: ClipOval(
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: imageUrl.startsWith('http')
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.indigo[50],
                                        child: const Icon(Icons.layers, color: Colors.indigo),
                                      );
                                    },
                                  )
                                : Container(
                                    color: Colors.indigo[50],
                                    child: const Icon(Icons.layers, color: Colors.indigo),
                                  ),
                          ),
                        ),
                        title: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Código: ${p['code']}  |  Precio: \$${p['price']}  |  Stock: ${p['stock']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: esAdmin ? () => _showForm(p) : null,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: esAdmin ? () => _deleteProduct(p['id']) : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: esAdmin
          ? FloatingActionButton(
              backgroundColor: Colors.indigo[900],
              foregroundColor: Colors.white,
              onPressed: () => _showForm(null),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}