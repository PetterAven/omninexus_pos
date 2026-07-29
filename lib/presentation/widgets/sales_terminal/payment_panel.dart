import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/payment_terminal_service.dart';
import '../../providers/cart_controller.dart';
import '../../providers/checkout_controller.dart';
import '../../screens/payment_terminal_settings_screen.dart';

class PaymentPanel extends ConsumerWidget {
  final bool isWide;
  final TextEditingController cashController;
  final String? linkedChatId;
  final String? linkedUsername;
  final VoidCallback onClearCart;

  const PaymentPanel({
    super.key,
    required this.isWide,
    required this.cashController,
    this.linkedChatId,
    this.linkedUsername,
    required this.onClearCart,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkoutState = ref.watch(checkoutControllerProvider);
    final isProcessingPayment = checkoutState.isLoading;
    final paymentErrorText =
        checkoutState.hasError ? checkoutState.error.toString() : null;
    final total = ref.watch(cartTotalProvider);
    final cartIsEmpty = ref.watch(cartControllerProvider).isEmpty;

    return Container(
      margin: isWide
          ? const EdgeInsets.only(top: 16, bottom: 16, right: 16)
          : const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      padding: const EdgeInsets.all(20.0),
      // Evita el desbordamiento (Overflow) en pantallas pequeñas
      child: SingleChildScrollView(
        child: isProcessingPayment
            ? _buildProcessing()
            : _buildForm(
                context,
                ref,
                total: total,
                paymentErrorText: paymentErrorText,
                cartIsEmpty: cartIsEmpty,
              ),
      ),
    );
  }

  Widget _buildProcessing() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF232D37)),
          SizedBox(height: 15),
          Text(
            'Procesando venta y emitiendo comprobantes...',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _payCash(
    WidgetRef ref, {
    required double total,
    required double cashReceived,
  }) {
    ref.read(checkoutControllerProvider.notifier).payCash(
          total: total,
          cashReceived: cashReceived,
          cartItems: ref.read(cartControllerProvider),
          linkedChatId: linkedChatId,
          linkedUsername: linkedUsername,
        );
  }

  // Modal interactivo para Recargas Telefónicas / Tiempo Aire
  void _showRechargeDialog(BuildContext context) {
    final phoneController = TextEditingController();
    String selectedCarrier = 'Telcel';
    double selectedAmount = 50.0;

    showDialog(
      context: context,
      builder: (context) {
        // StatefulBuilder permite actualizar el estado interno del Modal
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.phone_android, color: Colors.purple),
                  SizedBox(width: 8),
                  Text('Recarga de Tiempo Aire'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selecciona la Compañía:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCarrier,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: ['Telcel', 'Movistar', 'AT&T', 'Bait', 'Unefon']
                          .map((carrier) => DropdownMenuItem(
                                value: carrier,
                                child: Text(carrier),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setStateModal(() => selectedCarrier = val);
                        }
                      },
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Número Telefónico (10 dígitos):',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      decoration: const InputDecoration(
                        hintText: 'ej. 5512345678',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Monto de Recarga:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [20.0, 30.0, 50.0, 100.0, 200.0, 500.0].map((monto) {
                        final isSelected = selectedAmount == monto;
                        return ChoiceChip(
                          label: Text('\$$monto'),
                          selected: isSelected,
                          selectedColor: Colors.purple.shade100,
                          onSelected: (selected) {
                            if (selected) {
                              setStateModal(() => selectedAmount = monto);
                            }
                          },
                        );
                      }).toList(),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade700,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final phone = phoneController.text.trim();
                    if (phone.length < 10) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ingresa un número telefónico válido a 10 dígitos.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '✅ Recarga de \$$selectedAmount para $selectedCarrier al $phone procesada correctamente.',
                        ),
                        backgroundColor: Colors.green.shade700,
                      ),
                    );
                  },
                  child: const Text('Realizar Recarga'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildForm(
    BuildContext context,
    WidgetRef ref, {
    required double total,
    required String? paymentErrorText,
    required bool cartIsEmpty,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'RESUMEN DE COBRO',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 15),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL A PAGAR:',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF232D37),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '💵 OPCIÓN A: PAGO EFECTIVO',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: cashController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'Monto Recibido',
            prefixText: '\$ ',
            errorText: paymentErrorText,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          onSubmitted: (_) {
            if (total > 0) {
              double cash = double.tryParse(cashController.text) ?? 0.0;
              _payCash(ref, total: total, cashReceived: cash);
            }
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final billete in [20.0, 50.0, 100.0, 200.0, 500.0])
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green.shade800,
                  side: BorderSide(color: Colors.green.shade300),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                onPressed: () {
                  double current = double.tryParse(cashController.text) ?? 0.0;
                  double nuevo = current + billete;
                  cashController.text = nuevo % 1 == 0
                      ? nuevo.toStringAsFixed(0)
                      : nuevo.toStringAsFixed(2);
                  ref.read(checkoutControllerProvider.notifier).reset();
                },
                child: Text(
                  '+\$${billete.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blueGrey.shade700,
                side: BorderSide(color: Colors.blueGrey.shade200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              onPressed: () {
                cashController.text = total % 1 == 0
                    ? total.toStringAsFixed(0)
                    : total.toStringAsFixed(2);
                ref.read(checkoutControllerProvider.notifier).reset();
              },
              child: const Text('Exacto',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade200),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              onPressed: () {
                cashController.clear();
                ref.read(checkoutControllerProvider.notifier).reset();
              },
              child: const Icon(Icons.backspace_outlined, size: 16),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          icon: const Icon(Icons.payments_outlined, size: 20),
          label: const Text('Registrar Pago Efectivo',
              style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: total > 0
              ? () {
                  double cash = double.tryParse(cashController.text) ?? 0.0;
                  _payCash(ref, total: total, cashReceived: cash);
                }
              : null,
        ),
        const SizedBox(height: 14),
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('O', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 14),
        Consumer(
          builder: (context, ref, _) {
            final terminalReadyAsync = ref.watch(paymentTerminalReadyProvider);
            final terminalReady = terminalReadyAsync.value ?? false;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '💳 OPCIÓN B: PAGO CON TARJETA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: Colors.blue,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings, size: 18, color: Colors.blueGrey),
                      tooltip: 'Configurar terminal de cobro',
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PaymentTerminalSettingsScreen()),
                        );
                        ref.invalidate(paymentTerminalReadyProvider);
                      },
                    ),
                  ],
                ),
                if (!terminalReady)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text(
                      '⚠️ Configura una terminal (Clip o Mercado Pago) para habilitar cobro con tarjeta.',
                      style: TextStyle(fontSize: 11, color: Colors.orange),
                    ),
                  ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.credit_card_outlined, size: 20),
                  label: const Text(
                    'Cobrar con Tarjeta',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: (total > 0 && terminalReady)
                      ? () {
                          ref.read(checkoutControllerProvider.notifier).payCard(
                                total: total,
                                cartItems: ref.read(cartControllerProvider),
                                linkedChatId: linkedChatId,
                                linkedUsername: linkedUsername,
                              );
                        }
                      : null,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('O', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 14),
        // OPCIÓN C: RECARGAS / SERVICIOS
        const Text(
          '📱 OPCIÓN C: SERVICIOS Y RECARGAS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12.5,
            color: Colors.purple,
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: const Icon(Icons.phone_android_outlined, size: 20),
          label: const Text(
            'Recargas / Tiempo Aire',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          onPressed: () => _showRechargeDialog(context),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Cancelar / Vaciar Carrito'),
          onPressed: cartIsEmpty ? null : onClearCart,
        ),
      ],
    );
  }
}