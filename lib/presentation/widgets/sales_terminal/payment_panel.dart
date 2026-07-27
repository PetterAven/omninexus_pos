import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/cart_controller.dart';
import '../../providers/checkout_controller.dart';

/// Panel de cobro (efectivo / tarjeta) de la Terminal de Ventas.
///
/// CORREGIDO: convertido a ConsumerWidget. Antes recibía 13 parámetros
/// -- `total`, `isProcessingPayment`, `paymentErrorText`, `cartIsEmpty`
/// y seis callbacks -- todos calculados/armados a mano en
/// `SalesTerminalScreen._buildPaymentPanel`. De esos, todo lo que era
/// pura lectura de un provider (total, loading, error, carrito vacío) o
/// una acción que solo necesitaba `ref` (agregar efectivo rápido, monto
/// exacto, limpiar campo, pagar en efectivo/tarjeta) se resolvió aquí
/// dentro. Solo sobreviven como parámetros: el layout (`isWide`), el
/// controller de texto (`cashController`, porque otros puntos de
/// `SalesTerminalScreen` como `_clearCart`/`_onCheckoutSuccess` también
/// necesitan limpiarlo), el cliente vinculado a Telegram (todavía vive
/// como estado local del State, no hay provider para eso aún) y
/// `onClearCart` (abre un diálogo de confirmación y resetea ese mismo
/// estado de Telegram -- no es algo que este widget deba decidir).
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
    final paymentErrorText = checkoutState.hasError ? checkoutState.error.toString() : null;
    final total = ref.watch(cartTotalProvider);
    final cartIsEmpty = ref.watch(cartControllerProvider).isEmpty;

    return Container(
      margin: isWide
          ? const EdgeInsets.only(top: 16, bottom: 16, right: 16)
          : const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      padding: const EdgeInsets.all(20.0),
      child: isProcessingPayment
          ? _buildProcessing()
          : _buildForm(context, ref, total: total, paymentErrorText: paymentErrorText, cartIsEmpty: cartIsEmpty),
    );
  }

  Widget _buildProcessing() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF232D37)),
          SizedBox(height: 15),
          Text('Procesando venta y emitiendo comprobantes...', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _payCash(WidgetRef ref, {required double total, required double cashReceived}) {
    ref.read(checkoutControllerProvider.notifier).payCash(
          total: total,
          cashReceived: cashReceived,
          cartItems: ref.read(cartControllerProvider),
          linkedChatId: linkedChatId,
          linkedUsername: linkedUsername,
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
        const Text('RESUMEN DE COBRO', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL A PAGAR:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF232D37))),
            ],
          ),
        ),
        const SizedBox(height: 25),
        const Text('💵 OPCIÓN A: PAGO EFECTIVO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
        const SizedBox(height: 8),
        TextField(
          controller: cashController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'Monto Recibido',
            prefixText: '\$ ',
            errorText: paymentErrorText,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) {
            if (total > 0) {
              double cash = double.tryParse(cashController.text) ?? 0.0;
              _payCash(ref, total: total, cashReceived: cash);
            }
          },
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
                onPressed: () {
                  double current = double.tryParse(cashController.text) ?? 0.0;
                  double nuevo = current + billete;
                  cashController.text =
                      nuevo % 1 == 0 ? nuevo.toStringAsFixed(0) : nuevo.toStringAsFixed(2);
                  ref.read(checkoutControllerProvider.notifier).reset();
                },
                child: Text('+\$${billete.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blueGrey.shade700,
                side: BorderSide(color: Colors.blueGrey.shade200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () {
                cashController.text = total % 1 == 0 ? total.toStringAsFixed(0) : total.toStringAsFixed(2);
                ref.read(checkoutControllerProvider.notifier).reset();
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
                cashController.clear();
                ref.read(checkoutControllerProvider.notifier).reset();
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
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.payments_outlined),
          label: const Text('Registrar Pago Efectivo', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: total > 0
              ? () {
                  double cash = double.tryParse(cashController.text) ?? 0.0;
                  _payCash(ref, total: total, cashReceived: cash);
                }
              : null,
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: const Icon(Icons.credit_card_outlined),
          label: const Text('Cobrar con Tarjeta (Débito/Crédito)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          onPressed: total > 0
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
        SizedBox(height: isWide ? 20 : 20),
        if (isWide) const Spacer(),
        if (!isWide) const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Cancelar / Vaciar Carrito'),
          onPressed: cartIsEmpty ? null : onClearCart,
        ),
      ],
    );
  }
}