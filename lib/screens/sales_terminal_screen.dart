import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; 
import 'package:pdf/pdf.dart'; 
import 'package:pdf/widgets.dart' as pw; 
import 'package:printing/printing.dart'; 
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
  final TextEditingController _cashController = TextEditingController();
  
  double _total = 0.0;
  bool _isProcessingPayment = false;
  String? _paymentErrorText;

  // ================= CREDENCIALES TELEGRAM =================
  final String _telegramBotToken = '8903317057:AAED_G8nbaMzMibTXySvCY7LFt6FjoMsqkE';
  final String _telegramChatId = '8940573921';

  // Algoritmo de conversión de totales monetarios a formato de texto legal en pesos
  String _convertirTotalALetras(double cantidad) {
    int entero = cantidad.floor();
    if (entero == 0) return "CERO PESOS 00/100 M.N.";
    
    final unidades = ["", "UN", "DOS", "TRES", "CUATRO", "CINCO", "SEIS", "SIETE", "OCHO", "NUEVE"];
    final decenas = ["", "DIEZ", "VEINTE", "TREINTA", "CUARENTA", "CINCUENTA", "SESENTA", "SETENTA", "OCHENTA", "NOVENTA"];
    final especiales = ["ONCE", "DOCE", "TRECE", "CATORCE", "QUINCE", "DIECISEIS", "DIECISIETE", "DIECIOCHO", "DIECINUEVE"];
    
    String letras = "";
    if (entero >= 100) {
      if (entero == 100) letras += "CIEN ";
      else if (entero < 200) letras += "CIENTO ";
      entero %= 100;
    }
    
    if (entero >= 11 && entero <= 19) {
      letras += especiales[entero - 11] + " ";
    } else {
      int dec = (entero / 10).floor();
      int uni = entero % 10;
      if (dec > 0) {
        letras += decenas[dec];
        if (uni > 0) letras += " Y ";
        else letras += " ";
      }
      if (uni > 0) {
        letras += unidades[uni] + " ";
      }
    }
    
    return "${letras.trim()} PESOS 00/100 M.N.";
  }

  void _calculateTotal() {
    double total = 0.0;
    for (var item in _cart) {
      total += (item['price'] ?? 0.0) * (item['quantity'] ?? 1);
    }
    setState(() {
      _total = total;
      if (_total == 0) _isProcessingPayment = false;
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
        if (_cart[existingIndex]['quantity'] < product['stock']) {
          _cart[existingIndex]['quantity'] += 1;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No hay más stock disponible.'))
          );
          return;
        }
      } else {
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

  void _clearCart() {
    if (_cart.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Vaciar carrito?'),
        content: const Text('Se eliminarán todos los productos agregados.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              setState(() {
                _cart.clear();
                _total = 0.0;
                _isProcessingPayment = false;
                _cashController.clear();
                _paymentErrorText = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Vaciar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSearchSubmit(String query) async {
    if (query.trim().isEmpty) return;
    final results = await DatabaseHelper.instance.searchProducts(query.trim());
    if (results.isNotEmpty) {
      _addProductToCart(results.first);
      _searchController.closeView('');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Producto no encontrado.'))
      );
    }
  }

  // ================= ENVÍO CLON REPLICA WALMART A TELEGRAM =================
  Future<void> _sendTicketToTelegram(List<Map<String, dynamic>> items, double total, double received, double change) async {
    if (_telegramBotToken.startsWith('TU_')) return;

    double subtotalImpuestos = total / 1.16;
    double ivaCalculado = total - subtotalImpuestos;
    int totalArticulos = items.fold(0, (sum, item) => sum + (item['quantity'] as int));

    final buffer = StringBuffer();
    buffer.writeln('✳️ *WALMART EXPRESS - COMPROBANTE DE VENTA* ✳️');
    buffer.writeln('`NUEVA WAL MART DE MEXICO S DE RL DE CV`');
    buffer.writeln('`RFC: NWM9709244W4`');
    buffer.writeln('`REGIMEN FISCAL - 601 GENERAL DE LEY`');
    buffer.writeln('`--------------------------------------`');
    buffer.writeln('📅 *FECHA:* ${DateTime.now().toString().substring(0, 19)}');
    buffer.writeln('`TDA#3812  OP#00000254  TE# 079  TR# 02410`');
    buffer.writeln('`--------------------------------------`');
    
    for (var item in items) {
      double sub = (item['price'] ?? 0.0) * (item['quantity'] ?? 1);
      buffer.writeln('`Código: ${item['code']}`');
      buffer.writeln(' *${item['name'].toString().toUpperCase()}*');
      buffer.writeln('  ${item['quantity']} X \$${(item['price'] ?? 0.0).toStringAsFixed(2)}   ->   *\$${sub.toStringAsFixed(2)}T*');
    }
    
    buffer.writeln('`--------------------------------------`');
    buffer.writeln('💰 *TOTAL:* `\$${total.toStringAsFixed(2)}`');
    buffer.writeln('💵 *EFECTIVO:* `\$${received.toStringAsFixed(2)}`');
    buffer.writeln('🔄 *CAMBIO:* `\$${change.toStringAsFixed(2)}`');
    buffer.writeln('`--------------------------------------`');
    buffer.writeln('🔤 _${_convertirTotalALetras(total)}_');
    buffer.writeln('`--------------------------------------`');
    buffer.writeln('📦 *ARTÍCULOS VENDIDOS:* `$totalArticulos`');
    buffer.writeln('⚖️ *IVA INCLUIDO (16%):* `\$${ivaCalculado.toStringAsFixed(2)}`');
    buffer.writeln('`--------------------------------------`');
    buffer.writeln('¡Venta realizada con éxito!');

    final url = Uri.parse('https://api.telegram.org/bot$_telegramBotToken/sendMessage');
    try {
      await http.post(url, body: {
        'chat_id': _telegramChatId,
        'text': buffer.toString(),
        'parse_mode': 'Markdown',
      });
    } catch (e) {
      debugPrint('Error enviando a Telegram: $e');
    }
  }

  // ================= ESTRUCTURA IMPRESIÓN PAPEL TÉRMICO (58MM) =================
  Future<void> _printPhysicalTicket(List<Map<String, dynamic>> items, double total, double received, double change) async {
    final pdf = pw.Document();
    double subtotalImpuestos = total / 1.16;
    double ivaCalculado = total - subtotalImpuestos;
    int totalArticulos = items.fold(0, (sum, item) => sum + (item['quantity'] as int));

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 2 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text('Walmart', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14))),
              pw.Center(child: pw.Text('Express', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
              pw.SizedBox(height: 4),
              pw.Center(child: pw.Text('NUEVA WAL MART DE MEXICO S DE RL DE CV', style: const pw.TextStyle(fontSize: 6), textAlign: pw.TextAlign.center)),
              pw.Center(child: pw.Text('RFC. NWM9709244W4', style: const pw.TextStyle(fontSize: 6))),
              pw.Center(child: pw.Text('REGIMEN FISCAL - 601', style: const pw.TextStyle(fontSize: 6))),
              pw.Center(child: pw.Text('GENERAL DE LEY PERSONAS MORALES', style: const pw.TextStyle(fontSize: 6))),
              pw.Text('------------------------------------', style: const pw.TextStyle(fontSize: 6)),
              pw.Text('FECHA: ${DateTime.now().toString().substring(0, 19)}', style: const pw.TextStyle(fontSize: 6)),
              pw.Text('TDA#3812  OP#00000254  TE# 079  TR# 02410', style: const pw.TextStyle(fontSize: 6)),
              pw.Text('------------------------------------', style: const pw.TextStyle(fontSize: 6)),
              
              ...items.map((item) {
                double subtotal = (item['price'] ?? 0.0) * (item['quantity'] ?? 1);
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(item['code'].toString(), style: const pw.TextStyle(fontSize: 6)),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(item['name'].toString().toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
                        pw.Text('\$${subtotal.toStringAsFixed(2)}T', style: const pw.TextStyle(fontSize: 7)),
                      ],
                    ),
                    pw.Text('  ${item['quantity']} X \$${(item['price'] ?? 0.0).toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 6)),
                  ],
                );
              }).toList(),
              
              pw.Text('------------------------------------', style: const pw.TextStyle(fontSize: 6)),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.Text('\$${total.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('EFECTIVO', style: const pw.TextStyle(fontSize: 7)),
                  pw.Text('\$${received.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 7)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('CAMBIO', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                  pw.Text('\$${change.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Text(_convertirTotalALetras(total), style: const pw.TextStyle(fontSize: 6, fontStyle: pw.FontStyle.italic)),
              pw.Text('------------------------------------', style: const pw.TextStyle(fontSize: 6)),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('ARTICULOS VENDIDOS', style: const pw.TextStyle(fontSize: 6)),
                  pw.Text('$totalArticulos', style: const pw.TextStyle(fontSize: 6)),
                ],
              ),
              pw.Text('IVA INCLUIDO: \$${ivaCalculado.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 6)),
              pw.Text('------------------------------------', style: const pw.TextStyle(fontSize: 6)),
              pw.Center(child: pw.Text('¡COMPRA EN LINEA EN WALMART.COM.MX!', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6))),
              pw.Center(child: pw.Text('*** GRACIAS POR SU PREFERENCIA ***', style: const pw.TextStyle(fontSize: 6))),
            ],
          );
        },
      ),
    );

    try {
      final printers = await Printing.listPrinters();
      final Printer thermalPrinter = printers.firstWhere(
        (printer) => 
          printer.name.toLowerCase().contains('pos') || 
          printer.name.toLowerCase().contains('thermal') || 
          printer.name.toLowerCase().contains('58') || 
          printer.name.toLowerCase().contains('xprinter'),
        orElse: () => printers.first,
      );

      await Printing.directPrintPdf(
        printer: thermalPrinter,
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      debugPrint('Error en hardware de impresión: $e');
    }
  }

  Future<void> _processLateralCheckout(double cashReceived) async {
    if (cashReceived < _total) {
      setState(() {
        _paymentErrorText = 'Monto inferior al total';
      });
      return;
    }

    final double change = cashReceived - _total;

    try {
      final List<Map<String, dynamic>> ticketItems = List.from(_cart);
      final double ticketTotal = _total;

      await DatabaseHelper.instance.registerSale(_total, _cart);

      _sendTicketToTelegram(ticketItems, ticketTotal, cashReceived, change);
      _printPhysicalTicket(ticketItems, ticketTotal, cashReceived, change);

      if (mounted) {
        setState(() {
          _cart.clear();
          _total = 0.0;
          _isProcessingPayment = false;
          _cashController.clear();
          _paymentErrorText = null;
        });

        _showWalmartTicket(ticketItems, ticketTotal, cashReceived, change);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error interno en la venta: $e'))
        );
      }
    }
  }

  // ================= TICKET EN PANTALLA TIPO COURIER WALMART =================
  void _showWalmartTicket(List<Map<String, dynamic>> items, double total, double cashReceived, double change) {
    double subtotalImpuestos = total / 1.16;
    double ivaCalculado = total - subtotalImpuestos;
    int totalArticulos = items.fold(0, (sum, item) => sum + (item['quantity'] as int));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        content: SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Walmart', style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 24, color: Colors.black)),
                const Text('Express', style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                const SizedBox(height: 5),
                const Text('NUEVA WAL MART DE MEXICO S DE RL DE CV', style: TextStyle(fontFamily: 'Courier', fontSize: 10, color: Colors.black), textAlign: TextAlign.center),
                const Text('RFC. NWM9709244W4  |  REGIMEN FISCAL: 601', style: TextStyle(fontFamily: 'Courier', fontSize: 9, color: Colors.black)),
                const Text('-------------------------------------', style: TextStyle(fontFamily: 'Courier', color: Colors.black)),
                Text('FECHA: ${DateTime.now().toString().substring(0,19)}', style: const TextStyle(fontFamily: 'Courier', fontSize: 11, color: Colors.black)),
                const Text('TDA#3812  OP#00000254  TE# 079  TR# 02410', style: TextStyle(fontFamily: 'Courier', fontSize: 10, color: Colors.black)),
                const Text('-------------------------------------', style: TextStyle(fontFamily: 'Courier', color: Colors.black)),
                
                ...items.map((item) {
                  double subtotal = (item['price'] ?? 0.0) * (item['quantity'] ?? 1);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['code'].toString(), style: const TextStyle(fontFamily: 'Courier', fontSize: 10, color: Colors.black54)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(item['name'].toString().toUpperCase(), style: const TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black)),
                            Text('\$${subtotal.toStringAsFixed(2)}T', style: const TextStyle(fontFamily: 'Courier', fontSize: 12, color: Colors.black)),
                          ],
                        ),
                        Text('  ${item['quantity']} X \$${(item['price'] ?? 0.0).toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'Courier', fontSize: 11, color: Colors.black54)),
                      ],
                    ),
                  );
                }).toList(),
                
                const Text('-------------------------------------', style: TextStyle(fontFamily: 'Courier', color: Colors.black)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL', style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black)),
                    Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('EFECTIVO', style: TextStyle(fontFamily: 'Courier', fontSize: 12, color: Colors.black)),
                    Text('\$${cashReceived.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'Courier', fontSize: 12, color: Colors.black)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('CAMBIO', style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, color: Colors.black)),
                    Text('\$${change.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green)),
                  ],
                ),
                const SizedBox(height: 5),
                Text(_convertirTotalALetras(total), style: const TextStyle(fontFamily: 'Courier', fontSize: 10, fontStyle: FontStyle.italic, color: Colors.black87)),
                const Text('-------------------------------------', style: TextStyle(fontFamily: 'Courier', color: Colors.black)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ARTICULOS VENDIDOS', style: TextStyle(fontFamily: 'Courier', fontSize: 11, color: Colors.black)),
                    Text('$totalArticulos', style: const TextStyle(fontFamily: 'Courier', fontSize: 11, color: Colors.black)),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('IVA INCLUIDO: \$${ivaCalculado.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'Courier', fontSize: 11, color: Colors.black)),
                ),
                const Text('-------------------------------------', style: TextStyle(fontFamily: 'Courier', color: Colors.black)),
                const SizedBox(height: 5),
                const Text('COMPRA EN LINEA EN WALMART.COM.MX', style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black)),
                const Text('*** VUELVA PRONTO ***', style: TextStyle(fontFamily: 'Courier', fontSize: 11, color: Colors.black)),
              ],
            ),
          ),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF232D37)),
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar Ticket', style: TextStyle(color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }

  // ================= PANEL INTEGRADO CON CONTROL DE CAJEROS =================
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
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
              ],
            ),
            content: SizedBox(
              width: 450,
              height: 400,
              child: Column(
                children: [
                  TabBar(
                    labelColor: const Color(0xFF232D37),
                    indicatorColor: const Color(0xFF232D37),
                    tabs: [
                      const Tab(text: 'Corte de Caja'),
                      if (widget.userRole == 'Administrador' || widget.userRole == 'admin') const Tab(text: 'Gestión de Personal'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: TabBarView(
                      children: [
                        Column(
                          children: [
                            Card(
                              color: Colors.green[50],
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('VENTAS ACUMULADAS:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text('\$${granTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: sales.isEmpty
                                  ? const Center(child: Text('Sin movimientos hoy.'))
                                  : ListView.builder(
                                      itemCount: sales.length,
                                      itemBuilder: (context, index) {
                                        final sale = sales[index];
                                        return ListTile(
                                          leading: const Icon(Icons.receipt_long, color: Colors.blueGrey),
                                          title: Text('Ticket ID: #${sale['id']}'),
                                          subtitle: Text(sale['date'].toString().substring(11, 19)),
                                          trailing: Text('\$${(sale['total'] ?? 0.0).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                        // PANEL DE EXCLUSIÓN TOTAL DE CAJEROS (VINCULADO AL BOTÓN DE ACCIÓN EN BASE DE DATOS)
                        if (widget.userRole == 'Administrador' || widget.userRole == 'admin')
                          users.isEmpty
                              ? const Center(child: Text('No hay cuentas creadas.'))
                              : ListView.builder(
                                  itemCount: users.length,
                                  itemBuilder: (context, index) {
                                    final user = users[index];
                                    return ListTile(
                                      leading: const Icon(Icons.person_outline, color: Color(0xFF232D37)),
                                      title: Text(user['username'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text('Puesto: ${user['role']}'),
                                      trailing: user['role'] == 'Administrador' || user['username'] == 'admin'
                                          ? const Tooltip(message: 'Cuenta Raíz Protegida', child: Icon(Icons.shield, color: Colors.amber))
                                          : IconButton(
                                              icon: const Icon(Icons.person_remove, color: Colors.redAccent),
                                              tooltip: 'Dar de baja inmediatamente',
                                              onPressed: () async {
                                                await DatabaseHelper.instance.deleteUser(user['username']);
                                                final updatedUsers = await DatabaseHelper.instance.getUsers();
                                                setDialogState(() { users = updatedUsers; });
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
    List<double> suggestions = [20, 50, 100, 200, 500, 1000];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text('Terminal de Ventas - Modulo: ${widget.userRole ?? "General"}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                Navigator.push(context, MaterialPageRoute(builder: (context) => InventoryScreen(userRole: widget.userRole ?? 'Cajero')));
              },
              icon: const Icon(Icons.inventory, color: Colors.greenAccent),
              label: const Text('Inventario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
          ],
          IconButton(icon: const Icon(Icons.logout, color: Colors.redAccent), tooltip: 'Cerrar Sesión', onPressed: () => Navigator.pop(context)),
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
                        onSubmitted: (value) => _handleSearchSubmit(value),
                        leading: const Icon(Icons.search),
                        hintText: 'Escribe nombre o código de barras...',
                      );
                    },
                    suggestionsBuilder: (BuildContext context, SearchController controller) {
                      if (controller.text.trim().isEmpty) {
                        return [const ListTile(title: Text('Comienza a escribir para buscar...'))];
                      }
                      return [
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: DatabaseHelper.instance.searchProducts(controller.text.trim()),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()));
                            }
                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return const ListTile(title: Text('No se encontraron productos'));
                            }
                            final results = snapshot.data!;
                            return Column(
                              children: results.map((product) {
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
                              }).toList(),
                            );
                          },
                        )
                      ];
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
                                      SizedBox(width: 30, child: Text('${item['quantity']}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline, color: Colors.blueGrey),
                                        onPressed: () {
                                          setState(() {
                                            if (item['quantity'] < (item['stock'] ?? 0)) {
                                              _cart[index]['quantity']++;
                                              _calculateTotal();
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock máximo alcanzado.')));
                                            }
                                          });
                                        },
                                      ),
                                      const SizedBox(width: 15),
                                      SizedBox(width: 80, child: Text('\$${((item['price'] ?? 0.0) * (item['quantity'] ?? 1)).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.right)),
                                      const SizedBox(width: 10),
                                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () { setState(() { _cart.removeAt(index); _calculateTotal(); }); }),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_isProcessingPayment ? 'Módulo de Pago' : 'Resumen', style: const TextStyle(color: Colors.white70, fontSize: 18)),
                          if (_cart.isNotEmpty && !_isProcessingPayment)
                            IconButton(icon: const Icon(Icons.delete_sweep, color: Colors.redAccent), tooltip: 'Vaciar todo', onPressed: _clearCart),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text('TOTAL A PAGAR', style: TextStyle(color: Colors.white60, fontSize: 14)),
                      Text('\$${_total.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontSize: 38, fontWeight: FontWeight.bold)),
                      const Divider(color: Colors.white24, height: 30),
                      
                      if (!_isProcessingPayment) ...[
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.greenAccent[700],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _cart.isEmpty ? null : () => setState(() => _isProcessingPayment = true),
                            child: const Text('COBRAR VENTA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ] else ...[
                        const Text('EFECTIVO RECIBIDO:', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _cashController,
                          keyboardType: TextInputType.number,
                          autofocus: true, 
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            fillColor: Colors.white.withOpacity(0.1),
                            filled: true,
                            prefixText: '\$ ',
                            prefixStyle: const TextStyle(color: Colors.white, fontSize: 20),
                            errorText: _paymentErrorText,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                          onChanged: (_) => setState(() => _paymentErrorText = null),
                          onSubmitted: (value) {
                            final cash = double.tryParse(value) ?? 0.0;
                            _processLateralCheckout(cash);
                          },
                        ),
                        const SizedBox(height: 15),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: suggestions.map((amt) {
                            return ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.12),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: const BorderSide(color: Colors.white30, width: 1),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                              child: Text('\$$amt', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              onPressed: () {
                                _cashController.text = amt.toStringAsFixed(0);
                                setState(() => _paymentErrorText = null);
                              },
                            );
                          }).toList(),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white38),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                ),
                                onPressed: () => setState(() {
                                  _isProcessingPayment = false;
                                  _cashController.clear();
                                  _paymentErrorText = null;
                                }),
                                child: const Text('Regresar'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.greenAccent[700],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                ),
                                onPressed: () {
                                  final cash = double.tryParse(_cashController.text) ?? 0.0;
                                  _processLateralCheckout(cash);
                                },
                                child: const Text('PROCESAR', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        )
                      ],
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