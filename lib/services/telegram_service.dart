import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio externo: encapsula la comunicación con la tabla
/// `telegram_customers` de Supabase para vincular un cliente por su
/// código de 4 dígitos. Antes esta consulta vivía directo dentro del
/// widget del diálogo, mezclando UI con acceso a datos.
class TelegramService {
  static final TelegramService instance = TelegramService._init();
  TelegramService._init();

  final _supabase = Supabase.instance.client;

  /// Busca una coincidencia activa por el código corto de 4 dígitos.
  /// Devuelve `null` si no existe ningún cliente con ese código.
  Future<Map<String, dynamic>?> buscarClientePorCodigo(String code) async {
    final response = await _supabase
        .from('telegram_customers')
        .select('chat_id, username, expires_at')
        .eq('short_code', code)
        .maybeSingle();

    return response == null ? null : Map<String, dynamic>.from(response);
  }
}
