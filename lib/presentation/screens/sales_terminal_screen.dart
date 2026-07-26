import 'package:flutter/material.dart';
import '../../core/sync_status.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/sales_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/sync_repository.dart';
import '../../services/ticket_telegram_service.dart';
import '../../services/ticket_pdf_service.dart';
import 'inventory_screen.dart';
import 'barcode_scanner_screen.dart';
import '../widgets/sales_terminal/payment_panel.dart';
import '../widgets/sales_terminal/sync_code_dialog.dart';
import '../widgets/sales_terminal/cart_and_search_section.dart';
import '../widgets/sales_terminal/ticket_receipt_dialog.dart';
import '../widgets/sales_terminal/sales_report_dialog.dart';

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

  @override
  void initState() {
    super.initState();
    // NUEVO: escucha productos escaneados desde otro dispositivo emparejado
    // con el mismo código de sincronización, y los agrega a este carrito.
    SyncRepository.instance.listenToRemoteCart((scannedProduct) {
      if (!mounted) return;
      _addProductToCart(scannedProduct);
    });
  }

  @override
  void dispose() {
    SyncRepository.instance.stopRemoteCartListen();
    _searchController.dispose();
    _cashController.dispose();
    super.dispose();
  }

  // ================= NUEVO: CÓDIGO DE SINCRONIZACIÓN PC <-> TELÉFONO =================
  void _showSyncCodeDialog() {
    showSyncCodeDialog(
      context,
      onCodeUpdated: () {
        // Reabrimos la escucha con el código nuevo.
        SyncRepository.instance.listenToRemoteCart((scannedProduct) {
          if (!mounted) return;
          _addProductToCart(scannedProduct);
        });
      },
    );
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

      await SalesRepository.instance.registerSale(_total, _cart);
      final telegramError = await TicketTelegramService.instance.sendReceipt(
        ticketItems, ticketTotal, cashReceived, change,
        isCard: false, linkedChatId: _linkedChatId, linkedUsername: _linkedUsername,
      );
      if (telegramError != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(telegramError), backgroundColor: Colors.orange, duration: const Duration(seconds: 5)),
        );
      }
      await TicketPdfService.instance.printReceipt(
        ticketItems, ticketTotal, cashReceived, change,
        isCard: false, linkedUsername: _linkedUsername,
      );

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
        showTicketReceiptDialog(context, items: ticketItems, total: ticketTotal, cashReceived: cashReceived, change: change, isCard: false, linkedUsername: _linkedUsername);
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

      await SalesRepository.instance.registerSale(_total, _cart);
      final telegramError = await TicketTelegramService.instance.sendReceipt(
        ticketItems, ticketTotal, ticketTotal, 0.0,
        isCard: true, linkedChatId: _linkedChatId, linkedUsername: _linkedUsername,
      );
      if (telegramError != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(telegramError), backgroundColor: Colors.orange, duration: const Duration(seconds: 5)),
        );
      }
      await TicketPdfService.instance.printReceipt(
        ticketItems, ticketTotal, ticketTotal, 0.0,
        isCard: true, linkedUsername: _linkedUsername,
      );

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
        showTicketReceiptDialog(context, items: ticketItems, total: ticketTotal, cashReceived: ticketTotal, change: 0.0, isCard: true, linkedUsername: _linkedUsername);
      }
    } catch (e) {
      setState(() { _isProcessingPayment = false; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // ================= BÚSQUEDA + ESCÁNER DE CÓDIGO DE BARRAS =================
  Future<void> _scanBarcode() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null || code.isEmpty || !mounted) return;

    final results = await ProductRepository.instance.searchProducts(code);
    if (!mounted) return;
    if (results.isNotEmpty) {
      final productMap = results.first.toMap();
      _addProductToCart(productMap);
      // NUEVO: transmite el producto escaneado a cualquier otro dispositivo
      // escuchando (típicamente la Terminal de Ventas en la PC).
      SyncRepository.instance.sendProductToRemoteCart(productMap);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se encontró ningún producto con el código "$code".')),
      );
    }
  }


  // ================= SECCIÓN: BUSCADOR + CARRITO (reutilizable en ambos layouts) =================
  Widget _buildSearchAndCart(BuildContext context, {required bool expandCart}) {
    return CartAndSearchSection(
      expandCart: expandCart,
      searchController: _searchController,
      cart: _cart,
      onAddProductToCart: _addProductToCart,
      onScanBarcode: _scanBarcode,
      onIncreaseQuantity: (index) {
        setState(() {
          final item = _cart[index];
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
      onDecreaseQuantity: (index) {
        setState(() {
          final item = _cart[index];
          if (item['quantity'] > 1) {
            item['quantity'] -= 1;
          } else {
            _cart.removeAt(index);
          }
          _calculateTotal();
        });
      },
    );
  }

  // ================= SECCIÓN: PANEL DE COBRO (reutilizable en ambos layouts) =================
  Widget _buildPaymentPanel(BuildContext context, {required bool isWide}) {
    return PaymentPanel(
      isWide: isWide,
      isProcessingPayment: _isProcessingPayment,
      total: _total,
      cashController: _cashController,
      paymentErrorText: _paymentErrorText,
      cartIsEmpty: _cart.isEmpty,
      onAddQuickCash: _addQuickCash,
      onSetExactAmount: () {
        setState(() {
          _cashController.text = _total % 1 == 0 ? _total.toStringAsFixed(0) : _total.toStringAsFixed(2);
          _paymentErrorText = null;
        });
      },
      onClearCash: () {
        setState(() {
          _cashController.clear();
          _paymentErrorText = null;
        });
      },
      onSubmitCash: _processLateralCheckout,
      onPayCash: () {
        double cash = double.tryParse(_cashController.text) ?? 0.0;
        _processLateralCheckout(cash);
      },
      onPayCard: _processCardCheckout,
      onClearCart: _clearCart,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        // CORREGIDO: título más corto en pantallas angostas. El título largo
        // + 4 acciones (una con texto dinámico como "@usuario") se salían del
        // ancho del teléfono y el AppBar de Flutter no hace wrap: los botones
        // que no caben simplemente se recortan/ocultan. En la PC (ventana
        // ancha) sí cabían todos, por eso en el celular "no aparecía" el
        // botón de sincronizar: no es que faltara, es que no cabía.
        title: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = MediaQuery.of(context).size.width < 600;
            return Text(
              isNarrow
                  ? 'Ventas'
                  : 'Terminal de Ventas - Modulo: ${widget.userRole ?? "General"}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        backgroundColor: const Color(0xFF232D37),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // El botón de sincronización queda SIEMPRE visible y fijo, en
          // todas las pantallas, porque es el más importante para que el
          // teléfono y la PC se emparejen.
          IconButton(
            icon: const Icon(Icons.sync_alt),
            tooltip: 'Código de sincronización (teléfono ↔ PC)',
            onPressed: _showSyncCodeDialog,
          ),
          Builder(
            builder: (context) {
              final isNarrow = MediaQuery.of(context).size.width < 600;

              // En pantallas anchas (PC) se muestran las 3 acciones restantes
              // igual que antes, en fila.
              if (!isNarrow) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      icon: Icon(
                        _linkedChatId != null ? Icons.telegram : Icons.telegram_outlined,
                        color: _linkedChatId != null ? Colors.blue.shade300 : Colors.white60,
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
                      onPressed: () => showSalesReportDialog(context, userRole: widget.userRole ?? 'Cajero'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.inventory_2_outlined),
                      tooltip: 'Inventario',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => InventoryScreen(userRole: widget.userRole ?? 'Cajero')),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                  ],
                );
              }

              // En pantallas angostas (celular) se colapsan en un menú "⋮"
              // para que nada se recorte ni quede oculto fuera de pantalla.
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  switch (value) {
                    case 'telegram':
                      _abrirVinculacionTelegram();
                      break;
                    case 'corte':
                      showSalesReportDialog(context, userRole: widget.userRole ?? 'Cajero');
                      break;
                    case 'inventario':
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => InventoryScreen(userRole: widget.userRole ?? 'Cajero')),
                      );
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'telegram',
                    child: Row(
                      children: [
                        Icon(
                          _linkedChatId != null ? Icons.telegram : Icons.telegram_outlined,
                          color: _linkedChatId != null ? Colors.blue : Colors.grey,
                        ),
                        const SizedBox(width: 10),
                        Text(_linkedUsername != null ? '@$_linkedUsername' : 'Vincular Cliente'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'corte',
                    child: Row(
                      children: [
                        Icon(Icons.analytics_outlined, color: Colors.grey),
                        SizedBox(width: 10),
                        Text('Corte y Personal'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'inventario',
                    child: Row(
                      children: [
                        Icon(Icons.inventory_2_outlined, color: Colors.grey),
                        SizedBox(width: 10),
                        Text('Inventario'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      // CORREGIDO/NUEVO: layout responsive. En pantallas anchas (PC/tablet)
      // se conserva el Row de dos columnas de siempre. En pantallas angostas
      // (teléfono) se apila todo en una Column con scroll, para que nada
      // quede comprimido ni oculto como pasaba antes.
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 800;

          if (isWide) {
            return Row(
              children: [
                Expanded(flex: 3, child: _buildSearchAndCart(context, expandCart: true)),
                Expanded(flex: 2, child: _buildPaymentPanel(context, isWide: true)),
              ],
            );
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                _buildSearchAndCart(context, expandCart: false),
                _buildPaymentPanel(context, isWide: false),
              ],
            ),
          );
        },
      ),
    );
  }
}