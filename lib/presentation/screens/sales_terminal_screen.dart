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
import 'login_screen.dart';
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
  // Controllers de texto y estado local de Telegram vinculados
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

  // Manejo de resultado de agregación al carrito
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
      case CartOperationResult.invalidWeight:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El peso o cantidad ingresada no es válida.')),
        );
        break;
      case CartOperationResult.notApplicableForWeighted:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este producto se vende por peso. Ajusta la cantidad desde el carrito.')),
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

  // ================= CIERRE DE SESIÓN =================
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Se cerrará tu sesión y se descartará el carrito actual si tiene productos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            child: const Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _logout() {
    ref.invalidate(cartControllerProvider);
    ref.invalidate(checkoutControllerProvider);
    ref.read(authControllerProvider.notifier).logout();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // ================= REACCIÓN AL RESULTADO DEL COBRO =================
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
  Widget _buildSearchAndCart(BuildContext context, {required bool expandCart}) {
    return CartAndSearchSection(
      expandCart: expandCart,
      searchController: _searchController,
      onScanBarcode: _scanBarcode,
    );
  }

  // ================= SECCIÓN: PANEL DE COBRO =================
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
    final userRole = ref.watch(currentUserProvider)?.role;

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
                  : 'Terminal de Ventas - Módulo: ${userRole ?? "General"}',
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

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AppBarPillButton(
                    icon: _linkedChatId != null
                        ? Icons.telegram
                        : Icons.telegram_outlined,
                    iconColor: _linkedChatId != null
                        ? Colors.blue.shade300
                        : Colors.white60,
                    label: _linkedUsername != null
                        ? '@$_linkedUsername'
                        : 'Cliente',
                    showLabel: !isNarrow,
                    highlighted: _linkedChatId != null,
                    onPressed: _abrirVinculacionTelegram,
                  ),
                  const SizedBox(width: 6),
                  _AppBarPillButton(
                    icon: Icons.analytics_outlined,
                    label: 'Corte',
                    showLabel: !isNarrow,
                    onPressed: () => showSalesReportDialog(context, ref),
                  ),
                  const SizedBox(width: 6),
                  _AppBarPillButton(
                    icon: Icons.inventory_2_outlined,
                    label: 'Inventario',
                    showLabel: !isNarrow,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => InventoryScreen(userRole: userRole ?? 'Cajero'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: _confirmLogout,
          ),
          const SizedBox(width: 6),
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

class _AppBarPillButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final bool showLabel;
  final bool highlighted;
  final VoidCallback onPressed;

  const _AppBarPillButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.iconColor,
    this.showLabel = true,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color resolvedIconColor = iconColor ?? Colors.white;
    final Color background = highlighted
        ? Colors.white.withOpacity(0.16)
        : Colors.white.withOpacity(0.06);
    final Color border = highlighted
        ? Colors.blue.shade300.withOpacity(0.6)
        : Colors.white.withOpacity(0.14);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border, width: 1),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: showLabel ? 12 : 8,
            vertical: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: resolvedIconColor),
              if (showLabel) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: highlighted ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}