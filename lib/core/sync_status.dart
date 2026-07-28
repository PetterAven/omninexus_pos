import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Estado reactivo de sincronización con Supabase.
///
/// Antes vivía como `static bool lastSyncOk` suelto: ningún widget podía
/// "observarlo" -- por eso InventoryScreen tenía que forzar el aviso a
/// mano enganchándose al ciclo de vida de productControllerProvider en
/// vez de simplemente leer este valor. Ahora es un Notifier real.
class SyncStatusController extends Notifier<bool> {
  @override
  bool build() => true;

  void update(bool value) {
    if (state == value) return; // evita reconstrucciones sin necesidad
    state = value;
  }
}

final syncStatusProvider = NotifierProvider<SyncStatusController, bool>(SyncStatusController.new);

/// Puente hacia código que NO es widget y por lo tanto no tiene `ref`:
/// ProductRepository, SalesRepository y AuthRepository escriben aquí
/// (`SyncStatus.lastSyncOk = true/false`) exactamente como siempre lo
/// hicieron -- no hubo que tocar esos 3 archivos.
///
/// Requiere que `SyncStatus.attach(container)` se llame una sola vez al
/// arrancar la app, con el mismo ProviderContainer que
/// UncontrolledProviderScope le pasa al resto de la UI (ver main.dart).
class SyncStatus {
  SyncStatus._();

  static ProviderContainer? _container;

  static void attach(ProviderContainer container) {
    _container = container;
  }

  static bool get lastSyncOk => _container?.read(syncStatusProvider) ?? true;

  static set lastSyncOk(bool value) {
    // Si algún día se llama antes de attach() (ej. un test que no monta
    // la app completa), simplemente no hay nadie escuchando -- no truena.
    _container?.read(syncStatusProvider.notifier).update(value);
  }
}