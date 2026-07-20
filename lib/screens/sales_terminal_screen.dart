import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; 
import 'package:pdf/pdf.dart'; 
import 'package:pdf/widgets.dart' as pw; 
import 'package:printing/printing.dart'; 
import '../models/database_helper.dart';
import 'inventory_screen.dart';

// Ruta ajustada para salir de 'screens' y entrar a 'widgets'
import '../widgets/telegram_link_dialog.dart'; 

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

  // ================= VARIABLES CLIENTE VINCULADO =================
  String? _linkedChatId;
  String? _linkedUsername;

  // ================= CREDENCIALES TELEGRAM =================
  final String _telegramBotToken = '8903317057:AAED_G8nbaMzMibTXySvCY7LFt6FjoMsqkE';
  final String _telegramChatId = '8940573921';

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

  void _addQuickCash(double amount) {
    double current = double.tryParse(_cashController.text) ?? 0.0;
    double nuevo = current + amount;
    _cashController.text = nuevo % 1 == 0 ? nuevo.toStringAsFixed(0) : nuevo.toStringAsFixed(2);
    setState(() { _paymentErrorText = null; });
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
                _linkedChatId = null; 
                _linkedUsername = null;
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

  void _abrirVinculacionTelegram() async {
    final Map<String, dynamic>? clienteVinculado = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => TelegramLinkDialog(), 
    );

    if (clienteVinculado != null) {
      setState(() {
        _linkedChatId = clienteVinculado['chat_id']?.toString();
        _linkedUsername = clienteVinculado['username'];
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Cliente "${_linkedUsername ?? 'ID: $_linkedChatId'}" vinculado exitosamente.'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
  }

  // ================= ENVIAR COMPROBANTE GENERAL (EFECTIVO O TARJETA) =================
  Future<void> _sendTicketToTelegram(List<Map<String, dynamic>> items, double total, double received, double change, {bool isCard = false}) async {
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
    if (isCard) {
      buffer.writeln('💳 *MÉTODO DE PAGO:* `TARJETA BANCARIA`');
    } else {
      buffer.writeln('💵 *EFECTIVO:* `\$${received.toStringAsFixed(2)}`');
    }
    buffer.writeln('🔄 *CAMBIO:* `\$${change.toStringAsFixed(2)}`');
    buffer.writeln('`--------------------------------------`');
    buffer.writeln('🔤 _${_convertirTotalALetras(total)}_');
    buffer.writeln('`--------------------------------------`');
    buffer.writeln('📦 *ARTÍCULOS VENDIDOS:* `$totalArticulos`');
    buffer.writeln('⚖️ *IVA INCLUIDO (16%):* `\$${ivaCalculado.toStringAsFixed(2)}`');
    
    if (_linkedUsername != null) {
      buffer.writeln('`--------------------------------------`');
      buffer.writeln('👤 *CLIENTE:* `@$_linkedUsername`');
    }
    
    buffer.writeln('`--------------------------------------`');
    buffer.writeln('¡Venta realizada con éxito!');

    final destinoChatId = _linkedChatId ?? _telegramChatId;
    final url = Uri.parse('https://api.telegram.org/bot$_telegramBotToken/sendMessage');
    
    try {
      await http.post(url, body: {
        'chat_id': destinoChatId,
        'text': buffer.toString(),
        'parse_mode': 'Markdown',
      });
    } catch (e) {
      debugPrint('Error enviando a Telegram: $e');
    }
  }

  // ================= IMPRIMIR TICKET FÍSICO (EFECTIVO O TARJETA) =================
  Future<void> _printPhysicalTicket(List<Map<String, dynamic>> items, double total, double received, double change, {bool isCard = false}) async {
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
                  pw.Text(isCard ? 'TARJETA' : 'EFECTIVO', style: const pw.TextStyle(fontSize: 7)),
                  pw.Text('\$${(isCard ? total : received).toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 7)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('CAMBIO', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                  pw.Text('\$${change.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                ],
              ),
              if (_linkedUsername != null) ...[
                pw.SizedBox(height: 2),
                pw.Text('CLIENTE: $_linkedUsername', style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold)),
              ],
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

  // ================= PROCESAR VENTA CON EFECTIVO =================
  Future<void> _processLateralCheckout(double cashReceived) async {
    if (cashReceived < _total) {
      setState(() { _paymentErrorText = 'Monto inferior al total'; });
      return;
    }

    setState(() { _isProcessingPayment = true; });
    final double change = cashReceived - _total;

    try {
      final List<Map<String, dynamic>> ticketItems = List.from(_cart);
      final double ticketTotal = _total;

      await DatabaseHelper.instance.registerSale(_total, _cart);
      await _sendTicketToTelegram(ticketItems, ticketTotal, cashReceived, change, isCard: false);
      await _printPhysicalTicket(ticketItems, ticketTotal, cashReceived, change, isCard: false);

      if (mounted) {
        setState(() {
          _cart.clear();
          _total = 0.0;
          _isProcessingPayment = false;
          _cashController.clear();
          _paymentErrorText = null;
          _linkedChatId = null; 
          _linkedUsername = null;
        });
        _showWalmartTicket(ticketItems, ticketTotal, cashReceived, change, isCard: false);
      }
    } catch (e) {
      setState(() { _isProcessingPayment = false; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // ================= PROCESAR VENTA CON TARJETA =================
  Future<void> _processCardCheckout() async {
    if (_cart.isEmpty) return;
    setState(() { _isProcessingPayment = true; });

    try {
      final List<Map<String, dynamic>> ticketItems = List.from(_cart);
      final double ticketTotal = _total;

      await DatabaseHelper.instance.registerSale(_total, _cart);
      await _sendTicketToTelegram(ticketItems, ticketTotal, ticketTotal, 0.0, isCard: true);
      await _printPhysicalTicket(ticketItems, ticketTotal, ticketTotal, 0.0, isCard: true);

      if (mounted) {
        setState(() {
          _cart.clear();
          _total = 0.0;
          _isProcessingPayment = false;
          _cashController.clear();
          _paymentErrorText = null;
          _linkedChatId = null; 
          _linkedUsername = null;
        });
        _showWalmartTicket(ticketItems, ticketTotal, ticketTotal, 0.0, isCard: true);
      }
    } catch (e) {
      setState(() { _isProcessingPayment = false; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // ================= TICKET EN PANTALLA =================
  void _showWalmartTicket(List<Map<String, dynamic>> items, double total, double cashReceived, double change, {required bool isCard}) {
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
                    Text(isCard ? 'PAGO CON TARJETA' : 'EFECTIVO', style: const TextStyle(fontFamily: 'Courier', fontSize: 12, color: Colors.black)),
                    Text('\$${(isCard ? total : cashReceived).toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'Courier', fontSize: 12, color: Colors.black)),
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
                if (_linkedUsername != null) ...[
                  const Text('-------------------------------------', style: TextStyle(fontFamily: 'Courier', color: Colors.black)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('CLIENTE VINCULADO: @$_linkedUsername', style: const TextStyle(fontFamily: 'Courier', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
                  ),
                ],
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

  void _showCreateUserDialog(void Function(void Function()) setDialogState, Future<void> Function() onCreated) {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String selectedRole = 'Cajero';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setInnerState) => AlertDialog(
          title: const Text('Nueva Cuenta de Empleado', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: userCtrl,
                decoration: const InputDecoration(labelText: 'Nombre de Usuario', prefixIcon: Icon(Icons.person)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Contraseña', prefixIcon: Icon(Icons.lock)),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: 'Puesto', prefixIcon: Icon(Icons.badge)),
                items: const [
                  DropdownMenuItem(value: 'Cajero', child: Text('Cajero')),
                  DropdownMenuItem(value: 'Administrador', child: Text('Administrador')),
                ],
                onChanged: (val) {
                  if (val != null) setInnerState(() => selectedRole = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF232D37)),
              onPressed: () async {
                if (userCtrl.text.trim().isEmpty || passCtrl.text.isEmpty) return;
                try {
                  // CORREGIDO: Garantizamos que currentOperatorRole no sea nulo enviando un valor por defecto
                  await DatabaseHelper.instance.registerUser(
                    currentOperatorRole: widget.userRole ?? 'Cajero',
                    newUsername: userCtrl.text.trim(),
                    newPassword: passCtrl.text,
                    newRole: selectedRole,
                  );
                  Navigator.pop(dialogContext);
                  await onCreated();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cuenta creada de forma exitosa.')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                  );
                }
              },
              child: const Text('Crear', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
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
      builder: (context) => DefaultTabController(
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
            child: StatefulBuilder(
              builder: (context, setDialogState) => Column(
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
                        if (widget.userRole == 'Administrador' || widget.userRole == 'admin')
                          Column(
                            children: [
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  icon: const Icon(Icons.person_add, size: 18),
                                  label: const Text('Nueva cuenta'),
                                  onPressed: () => _showCreateUserDialog(setDialogState, () async {
                                    users = await DatabaseHelper.instance.getUsers();
                                    setDialogState(() {});
                                  }),
                                ),
                              ),
                              Expanded(
                                child: users.isEmpty
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
                              ),
                            ],
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
        title: Text('Terminal de Ventas - Modulo: ${widget.userRole ?? "General"}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF232D37),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: Icon(
              _linkedChatId != null ? Icons.telegram : Icons.telegram_outlined,
              color: _linkedChatId != null ? Colors.blue.shade300 : Colors.white60
            ),
            label: Text(
              _linkedUsername != null ? '@$_linkedUsername' : 'Vincular Cliente',
              style: TextStyle(fontWeight: _linkedChatId != null ? FontWeight.bold : FontWeight.normal),
            ),
            onPressed: _abrirVinculacionTelegram,
          ),
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Corte y Personal',
            onPressed: _showSalesReport,
          ),
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined),
            tooltip: 'Inventario',
            // CORREGIDO: se agrega '?? Cajero' porque InventoryScreen exige un userRole no nulo (String)
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => InventoryScreen(userRole: widget.userRole ?? 'Cajero')),
              );
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Row(
        children: [
          // 🛒 COLUMNA IZQUIERDA: CONTROL DEL CARRITO Y BÚSQUEDA
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  SearchAnchor(
                    searchController: _searchController,
                    builder: (context, controller) => SearchBar(
                      controller: controller,
                      padding: const WidgetStatePropertyAll<EdgeInsets>(EdgeInsets.symmetric(horizontal: 16.0)),
                      leading: const Icon(Icons.search),
                      hintText: 'Buscar producto por nombre o código...',
                      onTap: () => controller.openView(),
                      onChanged: (_) => controller.openView(),
                    ),
                    suggestionsBuilder: (context, controller) async {
                      final results = await DatabaseHelper.instance.searchProducts(controller.text.trim());
                      return results.map((product) => ListTile(
                        title: Text(product['name']),
                        subtitle: Text('Código: ${product['code']} | Stock: ${product['stock']}'),
                        trailing: Text('\$${(product['price'] ?? 0.0).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () => _addProductToCart(product),
                      )).toList();
                    },
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: Card(
                      color: Colors.white,
                      elevation: 2,
                      child: _cart.isEmpty
                          ? const Center(child: Text('El carrito está vacío.', style: TextStyle(fontSize: 16, color: Colors.grey)))
                          : ListView.builder(
                              itemCount: _cart.length,
                              itemBuilder: (context, index) {
                                final item = _cart[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFF232D37),
                                    child: Text('${item['quantity']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                  title: Text(item['name'].toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('Código: ${item['code']} | unit: \$${item['price']}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('\$${((item['price'] ?? 0.0) * item['quantity']).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                        onPressed: () {
                                          setState(() {
                                            if (item['quantity'] > 1) {
                                              item['quantity'] -= 1;
                                            } else {
                                              _cart.removeAt(index);
                                            }
                                            _calculateTotal();
                                          });
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                        onPressed: () {
                                          setState(() {
                                            if (item['quantity'] < (item['stock'] ?? 0)) {
                                              item['quantity'] += 1;
                                              _calculateTotal();
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('No hay más stock disponible.'))
                                              );
                                            }
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
          ),
          
          // 💳 COLUMNA DERECHA: PASARELA MULTI-PAGO
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.only(top: 16, bottom: 16, right: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)]
              ),
              padding: const EdgeInsets.all(20.0),
              child: _isProcessingPayment
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF232D37)),
                          SizedBox(height: 15),
                          Text('Procesando venta y emitiendo comprobantes...', style: TextStyle(fontWeight: FontWeight.bold))
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('RESUMEN DE COBRO', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                        const SizedBox(height: 15),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
                          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('TOTAL A PAGAR:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              // CORREGIDO: Cambiado FontWeight.black por FontWeight.w900 para prevenir fallos de compilación
                              Text('\$${_total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF232D37))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 25),
                        const Text('💵 OPCIÓN A: PAGO EFECTIVO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _cashController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Monto Recibido',
                            prefixText: '\$ ',
                            errorText: _paymentErrorText,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final billete in [20.0, 50.0, 100.0, 200.0, 500.0])
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.green.shade800,
                                  side: BorderSide(color: Colors.green.shade300),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                onPressed: () => _addQuickCash(billete),
                                child: Text('+\$${billete.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blueGrey.shade700,
                                side: BorderSide(color: Colors.blueGrey.shade200),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              onPressed: () {
                                _cashController.text = _total % 1 == 0 ? _total.toStringAsFixed(0) : _total.toStringAsFixed(2);
                                setState(() { _paymentErrorText = null; });
                              },
                              child: const Text('Exacto', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                side: BorderSide(color: Colors.red.shade200),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              onPressed: () {
                                _cashController.clear();
                                setState(() { _paymentErrorText = null; });
                              },
                              child: const Icon(Icons.backspace_outlined, size: 18),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14)
                          ),
                          icon: const Icon(Icons.payments_outlined),
                          label: const Text('Registrar Pago Efectivo', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: _total > 0 ? () {
                            double cash = double.tryParse(_cashController.text) ?? 0.0;
                            _processLateralCheckout(cash);
                          } : null,
                        ),
                        const SizedBox(height: 20),
                        const Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('O', style: TextStyle(color: Colors.grey))),
                            Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text('💳 OPCIÓN B: PAGO CON TARJETA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                          ),
                          icon: const Icon(Icons.credit_card_outlined),
                          label: const Text('Cobrar con Tarjeta (Débito/Crédito)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          onPressed: _total > 0 ? _processCardCheckout : null,
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Cancelar / Vaciar Carrito'),
                          onPressed: _cart.isEmpty ? null : _clearCart,
                        )
                      ],
                    ),
            ),
          )
        ],
      ),
    );
  }
}
