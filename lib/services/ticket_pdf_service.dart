import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/utils/currency_to_words.dart';

/// Genera el PDF del ticket (formato térmico 58mm) y lo envía a la
/// impresora térmica conectada, si hay una disponible.
///
/// Extraído de `SalesTerminalScreen._printPhysicalTicket`. No depende de
/// `BuildContext`: si no hay impresoras o falla el hardware, simplemente
/// no imprime (mismo comportamiento silencioso que tenía el original,
/// documentado aquí en vez de perdido en medio de un widget de 1400
/// líneas).
class TicketPdfService {
  static final TicketPdfService instance = TicketPdfService._init();
  TicketPdfService._init();

  Future<void> printReceipt(
    List<Map<String, dynamic>> items,
    double total,
    double received,
    double change, {
    bool isCard = false,
    String? linkedUsername,
  }) async {
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
              pw.Center(child: pw.Text('Abarrotes', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14))),
              pw.Center(child: pw.Text('Doña Mary', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
              pw.SizedBox(height: 4),
              pw.Center(child: pw.Text('Tu tienda de confianza', style: const pw.TextStyle(fontSize: 6), textAlign: pw.TextAlign.center)),
              pw.Text('------------------------------------', style: const pw.TextStyle(fontSize: 6)),
              pw.Text('FECHA: ${DateTime.now().toString().substring(0, 19)}', style: const pw.TextStyle(fontSize: 6)),
              pw.Text('Gracias por tu compra', style: const pw.TextStyle(fontSize: 6)),
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
              }),
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
              if (linkedUsername != null) ...[
                pw.SizedBox(height: 2),
                pw.Text('CLIENTE: $linkedUsername', style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold)),
              ],
              pw.SizedBox(height: 3),
              pw.Text(totalEnLetras(total), style: pw.TextStyle(fontSize: 6, fontStyle: pw.FontStyle.italic)),
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
              pw.Center(child: pw.Text('*** GRACIAS POR SU PREFERENCIA ***', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6))),
            ],
          );
        },
      ),
    );

    try {
      final printers = await Printing.listPrinters();
      if (printers.isEmpty) {
        debugPrint('No se encontró ninguna impresora instalada en este equipo. Se omite la impresión física.');
        return;
      }
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
}