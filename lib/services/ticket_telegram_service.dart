import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../core/utils/currency_to_words.dart';

/// Envía el comprobante de una venta al chat de Telegram vinculado (o al
/// chat general de la tienda si no hay cliente vinculado).
///
/// Refactorizado para usar variables de entorno vía `flutter_dotenv` 
/// evitando la exposición de tokens y claves en el repositorio.
class TicketTelegramService {
  static final TicketTelegramService instance = TicketTelegramService._init();
  TicketTelegramService._init();

  // Obtiene los valores desde el archivo .env con valores por defecto seguros
  String get _botToken => dotenv.env['TELEGRAM_BOT_TOKEN'] ?? '';
  String get _fallbackChatId => dotenv.env['TELEGRAM_CHAT_ID'] ?? '';

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
    if (_botToken.isEmpty || _botToken.startsWith('TU_')) {
      debugPrint('⚠️ Token de Telegram no configurado en .env');
      return '⚠️ No se configuró el token de Telegram en el archivo .env';
    }

    double subtotalImpuestos = total / 1.16;
    double ivaCalculado = total - subtotalImpuestos;
    // CORREGIDO: item['quantity'] viene de CartItem.toMap(), y
    // CartItem.quantity es `double` desde que se agregó venta a granel
    // (kg/litros con decimales). El `as int` de aquí era exactamente lo
    // que tronaba con "type 'double' is not a subtype of type 'int'"
    // apenas se cobraba cualquier producto (incluso uno normal, porque
    // 1.0 sigue siendo double). Con `num` acepta ambos sin crashear.
    num totalArticulos = items.fold(0, (sum, item) => sum + ((item['quantity'] as num?) ?? 0));

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
    if (destinoChatId.isEmpty) {
      return '⚠️ No hay un Chat ID de destino configurado para Telegram.';
    }

    final url = Uri.parse('https://api.telegram.org/bot$_botToken/sendMessage');

    try {
      final response = await http.post(url, body: {
        'chat_id': destinoChatId,
        'text': buffer.toString(),
        'parse_mode': 'Markdown',
      });

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