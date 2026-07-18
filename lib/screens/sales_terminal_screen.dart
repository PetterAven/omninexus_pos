import 'package:flutter/material.dart';
import '../models/database_helper.dart';
import 'inventory_screen.dart';

class SalesTerminalScreen extends StatefulWidget {
  final String? userRole; 

  const SalesTerminalScreen({Key? key, this.userRole}) : super(key: key);

  @override
  State<SalesTerminalScreen> createState() => _SalesTerminalScreenState();
}

class _SalesTerminalScreenState extends State<SalesTerminalScreen> {
  final List<Map<String, dynamic>> _cart = [];
  final SearchController _searchController = SearchController();
  double _total = 0.0;

  void _calculateTotal() {
    double total = 0.0;
    for (var item in _cart) {
      total += (item['price'] ?? 0.0) * (item['quantity'] ?? 1);
    }
    setState(() {
      _total = total;
    });
  }

  void _addProductToCart(Map<String, dynamic> product) {
    if ((product['stock'] ?? 0) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este producto no tiene stock disponible.'))
      );
      return;
    }

    setState(() {
      final existingIndex = _cart.indexWhere((item) => item['code'] == product['code']);
      
      if (existingIndex >= 0) {
        // Validar que no exceda el stock al agregar repetidamente desde la barra de búsqueda
        if (_cart[existingIndex]['quantity'] < product['stock']) {
          _cart[existingIndex]['quantity'] += 1;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No hay más stock disponible de este producto.'))
          );
          return;
        }
      } else {
        // Guardamos también el stock máximo en el carrito para las validaciones de los botones + y -
        _cart.add({
          'code': product['code'],
          'name': product['name'],
          'price': product['price'],
          'stock': product['stock'], 
          'quantity': 1,
        });
      }
      _searchController.clear();
      _calculateTotal();
    });
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El carrito está vacío.'))
      );
      return;
    }

    try {
      final List<Map<String, dynamic>> ticketItems = List.from(_cart);
      final double ticketTotal = _total;

      await DatabaseHelper.instance.registerSale(_total, _cart);

      if (mounted) {
        setState(() {
          _cart.clear();
          _total = 0.0;
        });
        
        _showWalmartTicket(ticketItems, ticketTotal);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar la venta: $e'))
        );
      }
    }
  }

  void _showWalmartTicket(List<Map<String, dynamic>> items, double total) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        content: Container(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('*** OMNINEXUS POS ***', style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
              const Text('WALMART STYLE STORE', style: TextStyle(fontFamily: 'Courier', fontSize: 12, color: Colors.black)),
              const Text('Pachuca, Hidalgo, México', style: TextStyle(fontFamily: 'Courier', fontSize: 12, color: Colors.black)),
              const Text('--------------------------------', style: TextStyle(fontFamily: 'Courier', color: Colors.black)),
              Text('FECHA: ${DateTime.now().toString().substring(0,19)}', style: const TextStyle(fontFamily: 'Courier', fontSize: 12, color: Colors.black)),
              const Text('--------------------------------', style: TextStyle(fontFamily: 'Courier', color: Colors.black)),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('ARTICULO', style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, color: Colors.black)),
                  Text('TOTAL', style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, color: Colors.black)),
                ],
              ),
              const Text('--------------------------------', style: TextStyle(fontFamily: 'Courier', color: Colors.black)),
              ...items.map((item) {
                double subtotal = (item['price'] ?? 0.0) * (item['quantity'] ?? 1);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['name'].toString().toUpperCase(), style: const TextStyle(fontFamily: 'Courier', fontSize: 13, color: Colors.black)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('  ${item['quantity']} x \$${(item['price'] ?? 0.0).toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'Courier', fontSize: 12, color: Colors.grey)),
                          Text('\$${subtotal.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'Courier', fontSize: 13, color: Colors.black)),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
              const Text('--------------------------------', style: TextStyle(fontFamily: 'Courier', color: Colors.black)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TOTAL:', style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                  Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                ],
              ),
              const Text('--------------------------------', style: TextStyle(fontFamily: 'Courier', color: Colors.black)),
              const SizedBox(height: 10),
              const Text('GRACIAS POR SU COMPRA', style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, color: Colors.black)),
              const Text('*** VUELVA PRONTO ***', style: TextStyle(fontFamily: 'Courier', fontSize: 12, color: Colors.black)),
            ],
          ),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF232D37)),
              onPressed: () => Navigator.pop(context),
              child: const Text('Listo', style: TextStyle(color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }

  void _showSalesReport() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> sales = await db.query('sales', orderBy: 'id DESC');
    List<Map<String, dynamic>> users = await DatabaseHelper.instance.getUsers();
    
    double granTotal = 0.0;
    for (var sale in sales) {
      granTotal += sale['total'] ?? 0.0;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => DefaultTabController(
          length: (widget.userRole == 'Administrador' || widget.userRole == 'admin') ? 2 : 1,
          child: AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.analytics, color: Color(0xFF232D37)),
                    SizedBox(width: 10),
                    Text('Panel de Control', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            content: Container(
              width: 450,
              height: 400,
              child: Column(
                children: [
                  TabBar(
                    labelColor: const Color(0xFF232D37),
                    indicatorColor: const Color(0xFF232D37),
                    tabs: [
                      const Tab(text: 'Corte de Caja'),
                      if (widget.userRole == 'Administrador' || widget.userRole == 'admin')
                        const Tab(text: 'Usuarios'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // PESTAÑA 1: CORTE DE CAJA
                        Column(
                          children: [
                            Card(
                              color: Colors.green[50],
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('TOTAL EN CAJA:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text('\$${granTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: sales.isEmpty
                                  ? const Center(child: Text('No hay ventas registradas hoy.'))
                                  : ListView.builder(
                                      itemCount: sales.length,
                                      itemBuilder: (context, index) {
                                        final sale = sales[index];
                                        return ListTile(
                                          leading: const Icon(Icons.receipt_long, color: Colors.blueGrey),
                                          title: Text('Venta #${sale['id']}'),
                                          subtitle: Text(sale['date'].toString().substring(11, 19)),
                                          trailing: Text('\$${(sale['total'] ?? 0.0).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                        // PESTAÑA 2: GESTIÓN DE USUARIOS
                        if (widget.userRole == 'Administrador' || widget.userRole == 'admin')
                          users.isEmpty
                              ? const Center(child: Text('No hay usuarios registrados.'))
                              : ListView.builder(
                                  itemCount: users.length,
                                  itemBuilder: (context, index) {
                                    final user = users[index];
                                    return ListTile(
                                      leading: const Icon(Icons.person_outline),
                                      title: Text(user['username'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text('Rol: ${user['role']}'),
                                      trailing: user['username'] == 'admin' 
                                          ? const Tooltip(message: 'Admin Base del Sistema', child: Icon(Icons.shield, color: Colors.amber))
                                          : IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                                              onPressed: () async {
                                                await DatabaseHelper.instance.deleteUser(user['username']);
                                                final updatedUsers = await DatabaseHelper.instance.getUsers();
                                                setDialogState(() {
                                                  users = updatedUsers;
                                                });
                                              },
                                            ),
                                    );
                                  },
                                ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          'Terminal de Ventas - Modulo: ${widget.userRole ?? "General"}', 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        backgroundColor: const Color(0xFF232D37),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton.icon(
            onPressed: _showSalesReport,
            icon: const Icon(Icons.bar_chart, color: Colors.orangeAccent),
            label: const Text('Corte/Historial', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          if (widget.userRole == 'Administrador' || widget.userRole == 'admin') ...[
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const InventoryScreen()),
                );
              },
              icon: const Icon(Icons.inventory, color: Colors.greenAccent),
              label: const Text('Inventario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
          ],
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Cerrar Sesión',
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  SearchAnchor(
                    searchController: _searchController,
                    builder: (BuildContext context, SearchController controller) {
                      return SearchBar(
                        controller: controller,
                        padding: const WidgetStatePropertyAll<EdgeInsets>(EdgeInsets.symmetric(horizontal: 16.0)),
                        onTap: () => controller.openView(),
                        onChanged: (_) => controller.openView(),
                        leading: const Icon(Icons.search),
                        hintText: 'Escribe nombre o código de barras...',
                      );
                    },
                    suggestionsBuilder: (BuildContext context, SearchController controller) async {
                      final results = await DatabaseHelper.instance.searchProducts(controller.text.trim());
                      return results.map((product) {
                        return ListTile(
                          leading: const Icon(Icons.shopping_basket),
                          title: Text(product['name']),
                          subtitle: Text('Código: ${product['code']} | Stock: ${product['stock']}'),
                          trailing: Text('\$${(product['price'] ?? 0.0).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                          onTap: () {
                            _addProductToCart(product);
                            controller.closeView('');
                          },
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: _cart.isEmpty
                          ? const Center(child: Text('Carrito vacío. Escanea o busca productos.'))
                          : ListView.separated(
                              itemCount: _cart.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = _cart[index];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  title: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  subtitle: Text('Precio unitario: \$${(item['price'] ?? 0.0).toStringAsFixed(2)}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // BOTÓN DE RESTAR
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, color: Colors.blueGrey),
                                        onPressed: () {
                                          setState(() {
                                            if (item['quantity'] > 1) {
                                              _cart[index]['quantity']--;
                                            } else {
                                              _cart.removeAt(index);
                                            }
                                            _calculateTotal();
                                          });
                                        },
                                      ),
                                      // CANTIDAD ACTUAL
                                      SizedBox(
                                        width: 30,
                                        child: Text(
                                          '${item['quantity']}', 
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                                        ),
                                      ),
                                      // BOTÓN DE SUMAR
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline, color: Colors.blueGrey),
                                        onPressed: () {
                                          setState(() {
                                            if (item['quantity'] < (item['stock'] ?? 0)) {
                                              _cart[index]['quantity']++;
                                              _calculateTotal();
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Stock máximo alcanzado.'))
                                              );
                                            }
                                          });
                                        },
                                      ),
                                      const SizedBox(width: 15),
                                      // SUBTOTAL DEL ARTÍCULO
                                      SizedBox(
                                        width: 80,
                                        child: Text(
                                          '\$${((item['price'] ?? 0.0) * (item['quantity'] ?? 1)).toStringAsFixed(2)}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      // BOTÓN ELIMINAR
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () {
                                          setState(() {
                                            _cart.removeAt(index);
                                            _calculateTotal();
                                          });
                                        },
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
            const SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: Card(
                color: const Color(0xFF232D37),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Resumen', style: TextStyle(color: Colors.white70, fontSize: 18)),
                      const SizedBox(height: 10),
                      const Text('TOTAL A COBRAR', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w300)),
                      Text(
                        '\$${_total.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.greenAccent, fontSize: 36, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent[700],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _checkout,
                          child: const Text('COBRAR AHORA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}