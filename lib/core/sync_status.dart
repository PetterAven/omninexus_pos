/// Bandera compartida y simple para que la UI sepa si la última
/// operación contra Supabase sí llegó o se quedó en modo local.
///
/// Antes vivía como un campo público suelto dentro de DatabaseHelper
/// (`lastSyncOk`). Ahora que la lógica se repartió entre varios
/// repositorios (productos, ventas, usuarios), todos comparten esta
/// misma bandera desde un solo lugar en vez de tener cada quien la suya.
class SyncStatus {
  SyncStatus._();
  static bool lastSyncOk = true;
}
