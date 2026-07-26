import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/utils/currency_to_words.dart';

/// Envía el comprobante de una venta al chat de Telegram vinculado (o al
/// chat general de la tienda si no hay cliente vinculado).
///
/// Extraído de `SalesTerminalScreen._sendTicketToTelegram`. Es lógica de
/// red pura -- no depende de `BuildContext` ni de `setState` -- así que
/// vive en `services/` junto a `TelegramService` (que resuelve otra parte
/// del mismo dominio: la vinculación de clientes).
///
/// TODO(seguridad): el bot token y chat id de fallback siguen hardcodeados
/// aquí, tal como estaban en el widget original. Deberían salir a
/// variables de entorno (`--dart-define` o `flutter_dotenv`) antes de
/// subir a producción -- quedó fuera del alcance de esta extracción para
/// no mezclar "mover código" con "cambiar comportamiento".
class TicketTelegramService {
  static final TicketTelegramService instance = TicketTelegramService._init();
  TicketTelegramService._init();

  final String _botToken = '8903317057:AAEcJArqTDlU-_EmTKhhbEyiyVLo1CzVcq4';
  final String _fallbackChatId = '8940573921';

  /// Devuelve `null` si el envío fue exitoso (HTTP 200), o un mensaje de
  /// error legible para mostrar en un SnackBar si algo falló.
  Future<String?> sendReceipt(
    List<Map<String, dynamic>> items,
    double total,
    double received,
    double change, {
    bool isCard = false,
    String? linkedChatId,
    String? linkedUsername,
  }) async {
    if (_botToken.startsWith('TU_')) return null;

    double subtotalImpuestos = total / 1.16;
    double ivaCalculado = total - subtotalImpuestos;
    int totalArticulos = items.fold(0, (sum, item) => sum + (item['quantity'] as int));

    final buffer = StringBuffer();
    buffer.writeln('✳️ *ABARROTES DOÑA MARY - COMPROBANTE DE VENTA* ✳️');
    buffer.writeln('`Tu tienda de confianza`');
    buffer.writeln('`--------------------------------------`');
    buffer.writeln('📅 *FECHA:* ${DateTime.now().toString().substring(0, 19)}');
    buffer.writeln('`Gracias por tu compra`');
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
    buffer.writeln('🔤 _${totalEnLetras(total)}_');
    buffer.writeln('`--------------------------------------`');
    buffer.writeln('📦 *ARTÍCULOS VENDIDOS:* `$totalArticulos`');
    buffer.writeln('⚖️ *IVA INCLUIDO (16%):* `\$${ivaCalculado.toStringAsFixed(2)}`');

    if (linkedUsername != null) {
      buffer.writeln('`--------------------------------------`');
      buffer.writeln('👤 *CLIENTE:* `@$linkedUsername`');
    }

    buffer.writeln('`--------------------------------------`');
    buffer.writeln('¡Venta realizada con éxito!');

    final destinoChatId = linkedChatId ?? _fallbackChatId;
    final url = Uri.parse('https://api.telegram.org/bot$_botToken/sendMessage');

    try {
      final response = await http.post(url, body: {
        'chat_id': destinoChatId,
        'text': buffer.toString(),
        'parse_mode': 'Markdown',
      });

      // CORREGIDO: http.post no lanza excepción si Telegram responde 400/401 —
      // esas son respuestas HTTP "válidas", solo que de error. Antes esto se
      // ignoraba por completo y el ticket se perdía sin que nadie se enterara.
      if (response.statusCode != 200) {
        debugPrint('❌ Telegram rechazó el ticket (${response.statusCode}): ${response.body}');
        return '⚠️ Telegram no aceptó el ticket (${response.statusCode}). Revisa el token o el formato del mensaje.';
      }
      return null;
    } catch (e) {
      debugPrint('Error de red enviando a Telegram: $e');
      return '⚠️ No se pudo contactar a Telegram: $e';
    }
  }
}