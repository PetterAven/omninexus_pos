import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/sync_repository.dart';
import '../../domain/entities/product.dart';
import '../providers/auth_controller.dart';
import '../providers/cart_controller.dart';
import '../providers/checkout_controller.dart';
import 'inventory_screen.dart';
import 'barcode_scanner_screen.dart';
import '../widgets/sales_terminal/payment_panel.dart';
import '../widgets/sales_terminal/sync_code_dialog.dart';
import '../widgets/sales_terminal/cart_and_search_section.dart';
import '../widgets/sales_terminal/ticket_receipt_dialog.dart';
import '../widgets/sales_terminal/sales_report_dialog.dart';
import '../widgets/telegram_link_dialog.dart';

class SalesTerminalScreen extends ConsumerStatefulWidget {
  const SalesTerminalScreen({super.key});

  @override
  ConsumerState<SalesTerminalScreen> createState() => _SalesTerminalScreenState();
}

class _SalesTerminalScreenState extends ConsumerState<SalesTerminalScreen> {
  // CORREGIDO: el carrito ya no vive aquí -- se movió a
  // cartControllerProvider (ver providers/cart_controller.dart). Este
  // State ya solo guarda lo que es puramente de esta pantalla: los
  // controllers de texto y el cliente de Telegram vinculado.
  final SearchController _searchController = SearchController();
  final TextEditingController _cashController = TextEditingController();

  // ================= VARIABLES CLIENTE VINCULADO =================
  String? _linkedChatId;
  String? _linkedUsername;

  @override
  void initState() {
    super.initState();
    SyncRepository.instance.listenToRemoteCart((scannedMap) {
      if (!mounted) return;
      final product = Product.fromMap(scannedMap);
      _handleAddProduct(product);
    });
  }

  @override
  void dispose() {
    SyncRepository.instance.stopRemoteCartListen();
    _searchController.dispose();
    _cashController.dispose();
    super.dispose();
  }

  // ================= CÓDIGO DE SINCRONIZACIÓN PC <-> TELÉFONO =================
  void _showSyncCodeDialog() {
    showSyncCodeDialog(
      context,
      onCodeUpdated: () {
        SyncRepository.instance.listenToRemoteCart((scannedMap) {
          if (!mounted) return;
          final product = Product.fromMap(scannedMap);
          _handleAddProduct(product);
        });
      },
    );
  }

  // CORREGIDO: reemplaza a la antigua _addProductToCart. La lógica de
  // stock/duplicados ahora vive en CartController.addProduct(); aquí
  // solo interpretamos el resultado para decidir qué SnackBar mostrar
  // (el controller no conoce BuildContext, y no debe conocerlo).
  void _handleAddProduct(Product product) {
    final result = ref.read(cartControllerProvider.notifier).addProduct(product);
    switch (result) {
      case CartOperationResult.outOfStock:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este producto no tiene stock disponible.')),
        );
        break;
      case CartOperationResult.noMoreStock:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay más stock disponible.')),
        );
        break;
      case CartOperationResult.success:
        _searchController.clear();
        break;
    }
  }

  void _clearCart() {
    if (ref.read(cartControllerProvider).isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Vaciar carrito?'),
        content: const Text('Se eliminarán todos los productos agregados.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              ref.read(cartControllerProvider.notifier).clear();
              setState(() {
                _cashController.clear();
                _linkedChatId = null;
                _linkedUsername = null;
              });
              ref.read(checkoutControllerProvider.notifier).reset();
              Navigator.pop(context);
            },
            child: const Text('Vaciar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _abrirVinculacionTelegram() async {
    final Map<String, dynamic>? clienteVinculado =
        await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const TelegramLinkDialog(),
    );

    if (clienteVinculado != null) {
      setState(() {
        _linkedChatId = clienteVinculado['chat_id']?.toString();
        _linkedUsername = clienteVinculado['username'];
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Cliente "${_linkedUsername ?? 'ID: $_linkedChatId'}" vinculado exitosamente.',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
  }

  // ================= REACCIÓN AL RESULTADO DEL COBRO =================
  // Se llama desde el ref.listen del build() cuando el checkoutControllerProvider
  // pasa de loading a data(null) con éxito: pinta el ticket, limpia el
  // carrito y muestra el aviso de Telegram si lo hubo.
  void _onCheckoutSuccess(CheckoutResult result) {
    ref.read(cartControllerProvider.notifier).clear();
    setState(() {
      _cashController.clear();
      _linkedChatId = null;
      _linkedUsername = null;
    });

    if (result.telegramWarning != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.telegramWarning!),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
    }

    showTicketReceiptDialog(
      context,
      items: result.items,
      total: result.total,
      cashReceived: result.cashReceived,
      change: result.change,
      isCard: result.isCard,
      linkedUsername: result.linkedUsername,
    );
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
      final product = results.first;
      _handleAddProduct(product);
      SyncRepository.instance.sendProductToRemoteCart(product.toMap());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se encontró ningún producto con el código "$code".'),
        ),
      );
    }
  }

  // ================= SECCIÓN: BUSCADOR + CARRITO =================
  // CORREGIDO: CartAndSearchSection ahora es ConsumerWidget y lee/muta
  // cartControllerProvider directo -- ya no necesita que le pasemos el
  // carrito ni los callbacks de agregar/incrementar/decrementar. Solo
  // le seguimos pasando lo que de verdad no puede resolver por sí solo:
  // el layout (expandCart), el controller de búsqueda, y la navegación
  // al escáner (que además sincroniza con el otro dispositivo).
  Widget _buildSearchAndCart(BuildContext context, {required bool expandCart}) {
    return CartAndSearchSection(
      expandCart: expandCart,
      searchController: _searchController,
      onScanBarcode: _scanBarcode,
    );
  }

  // ================= SECCIÓN: PANEL DE COBRO =================
  // CORREGIDO: PaymentPanel ahora es ConsumerWidget y resuelve total,
  // loading/error del cobro, "carrito vacío" y los tres flujos de pago
  // (efectivo por Enter, botón efectivo, tarjeta) directo contra los
  // providers. Aquí solo le seguimos pasando lo que sigue siendo estado
  // local de esta pantalla: el cashController compartido con
  // _clearCart/_onCheckoutSuccess, el cliente vinculado a Telegram, y
  // onClearCart (abre el diálogo de confirmación).
  Widget _buildPaymentPanel(BuildContext context, {required bool isWide}) {
    return PaymentPanel(
      isWide: isWide,
      cashController: _cashController,
      linkedChatId: _linkedChatId,
      linkedUsername: _linkedUsername,
      onClearCart: _clearCart,
    );
  }

  @override
  Widget build(BuildContext context) {
    // CORREGIDO: el rol ya no llega por constructor (widget.userRole);
    // se lee directo del provider derivado de la sesión activa. Como es
    // una variable local de build(), los closures de abajo (onPressed,
    // onSelected, etc.) la capturan sin problema y se actualiza sola
    // si el usuario logueado cambia.
    final userRole = ref.watch(currentUserProvider)?.role;

    // Escucha el checkoutControllerProvider para reaccionar UNA sola vez
    // cuando el cobro termina bien (loading -> data(null) con lastResult
    // lleno): pinta el ticket y limpia el carrito. Los estados de
    // loading/error ya se leen directo con ref.watch dentro de
    // _buildPaymentPanel para pintar el botón/el texto de error.
    ref.listen(checkoutControllerProvider, (previous, next) {
      final wasLoading = previous?.isLoading ?? false;
      if (wasLoading && next.hasValue && !next.hasError) {
        final controller = ref.read(checkoutControllerProvider.notifier);
        final result = controller.lastResult;
        if (result != null) {
          _onCheckoutSuccess(result);
          controller.reset();
        }
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = MediaQuery.of(context).size.width < 600;
            return Text(
              isNarrow
                  ? 'Ventas'
                  : 'Terminal de Ventas - Modulo: ${userRole ?? "General"}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        backgroundColor: const Color(0xFF232D37),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_alt),
            tooltip: 'Código de sincronización (teléfono ↔ PC)',
            onPressed: _showSyncCodeDialog,
          ),
          Builder(
            builder: (context) {
              final isNarrow = MediaQuery.of(context).size.width < 600;

              if (!isNarrow) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      icon: Icon(
                        _linkedChatId != null
                            ? Icons.telegram
                            : Icons.telegram_outlined,
                        color: _linkedChatId != null
                            ? Colors.blue.shade300
                            : Colors.white60,
                      ),
                      label: Text(
                        _linkedUsername != null
                            ? '@$_linkedUsername'
                            : 'Vincular Cliente',
                        style: TextStyle(
                          fontWeight: _linkedChatId != null
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      onPressed: _abrirVinculacionTelegram,
                    ),
                    IconButton(
                      icon: const Icon(Icons.analytics_outlined),
                      tooltip: 'Corte y Personal',
                      onPressed: () => showSalesReportDialog(context, ref),
                    ),
                    IconButton(
                      icon: const Icon(Icons.inventory_2_outlined),
                      tooltip: 'Inventario',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const InventoryScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                  ],
                );
              }

              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  switch (value) {
                    case 'telegram':
                      _abrirVinculacionTelegram();
                      break;
                    case 'corte':
                      showSalesReportDialog(context, ref);
                      break;
                    case 'inventario':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const InventoryScreen(),
                        ),
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
                          _linkedChatId != null
                              ? Icons.telegram
                              : Icons.telegram_outlined,
                          color:
                              _linkedChatId != null ? Colors.blue : Colors.grey,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _linkedUsername != null
                              ? '@$_linkedUsername'
                              : 'Vincular Cliente',
                        ),
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 800;

          if (isWide) {
            return Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildSearchAndCart(context, expandCart: true),
                ),
                Expanded(
                  flex: 2,
                  child: _buildPaymentPanel(context, isWide: true),
                ),
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