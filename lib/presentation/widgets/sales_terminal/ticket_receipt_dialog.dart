import 'package:flutter/material.dart';
import '../../../core/utils/currency_to_words.dart';

/// Muestra el ticket de la venta ya completada, en pantalla (además del
/// PDF térmico y el mensaje de Telegram que se generan por su cuenta).
///
/// Extraído de `SalesTerminalScreen._showWalmartTicket`. Solo lee datos
/// ya calculados por quien lo invoca -- no llama repositorios ni
/// modifica estado -- así que puede vivir como una función suelta en vez
/// de un widget con estado propio.
void showTicketReceiptDialog(
  BuildContext context, {
  required List<Map<String, dynamic>> items,
  required double total,
  required double cashReceived,
  required double change,
  required bool isCard,
  String? linkedUsername,
}) {
  double subtotalImpuestos = total / 1.16;
  double ivaCalculado = total - subtotalImpuestos;
  // CORREGIDO: mismo bug que en TicketTelegramService/TicketPdfService.
  num totalArticulos = items.fold(0, (sum, item) => sum + ((item['quantity'] as num?) ?? 0));

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
              const Text('Abarrotes', style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 24, color: Colors.black)),
              const Text('Doña Mary', style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
              const SizedBox(height: 5),
              const Text('Tu tienda de confianza', style: TextStyle(fontFamily: 'Courier', fontSize: 10, color: Colors.black), textAlign: TextAlign.center),
              const Text('-------------------------------------', style: TextStyle(fontFamily: 'Courier', color: Colors.black)),
              Text('FECHA: ${DateTime.now().toString().substring(0, 19)}', style: const TextStyle(fontFamily: 'Courier', fontSize: 11, color: Colors.black)),
              const Text('Gracias por tu compra', style: TextStyle(fontFamily: 'Courier', fontSize: 10, color: Colors.black)),
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
              }),
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
              Text(totalEnLetras(total), style: const TextStyle(fontFamily: 'Courier', fontSize: 10, fontStyle: FontStyle.italic, color: Colors.black87)),
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
              if (linkedUsername != null) ...[
                const Text('-------------------------------------', style: TextStyle(fontFamily: 'Courier', color: Colors.black)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('CLIENTE VINCULADO: @$linkedUsername', style: const TextStyle(fontFamily: 'Courier', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
                ),
              ],
              const Text('-------------------------------------', style: TextStyle(fontFamily: 'Courier', color: Colors.black)),
              const SizedBox(height: 5),
              const Text('*** VUELVA PRONTO ***', style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black)),
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
        ),
      ],
    ),
  );
}