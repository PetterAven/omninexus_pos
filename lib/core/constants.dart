/// Constantes globales de la app. Antes valores como el timeout de red
/// vivían como campos sueltos dentro de DatabaseHelper; ahora cualquier
/// repositorio los puede usar sin depender de esa clase.
class AppConstants {
  /// Tiempo máximo que esperamos una respuesta de Supabase antes de
  /// rendirnos y seguir en modo local. Sin esto, una red lenta o un
  /// firewall que descarta paquetes silenciosamente deja el "await"
  /// colgado para siempre.
  static const Duration networkTimeout = Duration(seconds: 6);
}
