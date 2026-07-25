import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../datasources/local/app_database.dart';

/// Repositorio del carrito remoto en tiempo real (Teléfono -> PC) y del
/// código de sincronización que empareja cada "caja". Antes vivía
/// suelto dentro de DatabaseHelper; es la última pieza que faltaba
/// mover para poder retirar esa clase por completo.
///
/// Usa un canal de "broadcast" de Supabase Realtime: no necesita tablas
/// nuevas ni políticas RLS, solo que el proyecto tenga Realtime activo
/// (viene activo por defecto). Por diseño de Supabase, un cliente NUNCA
/// recibe sus propios mensajes de vuelta (self: false es el
/// comportamiento por defecto), así que no hay riesgo de que un
/// dispositivo se duplique el producto a sí mismo.
class SyncRepository {
  static final SyncRepository instance = SyncRepository._init();
  SyncRepository._init();

  final _supabase = Supabase.instance.client;
  RealtimeChannel? _remoteCartChannel;

  /// Cada "caja" tiene su propio código de sincronización guardado
  /// localmente, y el canal se arma como 'pos-remote-cart-<código>', así
  /// solo se emparejan los dispositivos que comparten el mismo código.
  Future<String> getSyncCode() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('app_settings', where: 'key = ?', whereArgs: ['sync_code']);
    if (rows.isNotEmpty) return rows.first['value'] as String;
    return 'CAJA1'; // valor por defecto si nunca se ha configurado
  }

  Future<void> setSyncCode(String code) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'app_settings',
      {'key': 'sync_code', 'value': code.trim().toUpperCase()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // Si ya había un canal abierto con el código viejo, lo cerramos para
    // que la próxima escucha/envío use el nuevo código.
    stopRemoteCartListen();
  }

  /// Escucha productos escaneados desde otro dispositivo emparejado con
  /// el mismo código de sincronización, y los entrega mediante
  /// [onProductScanned]. Llamar en initState().
  Future<void> listenToRemoteCart(void Function(Map<String, dynamic> product) onProductScanned) async {
    final code = await getSyncCode();
    _remoteCartChannel = _supabase.channel('pos-remote-cart-$code');

    _remoteCartChannel!
        .onBroadcast(
          event: 'product_scanned',
          callback: (payload) {
            try {
              onProductScanned(Map<String, dynamic>.from(payload));
            } catch (e) {
              debugPrint('Error procesando producto remoto: $e');
            }
          },
        )
        .subscribe();
  }

  /// Manda un producto escaneado a cualquier otro dispositivo emparejado
  /// con el mismo código de sincronización.
  Future<void> sendProductToRemoteCart(Map<String, dynamic> product) async {
    try {
      if (_remoteCartChannel == null) {
        final code = await getSyncCode();
        final completer = Completer<void>();
        _remoteCartChannel = _supabase.channel('pos-remote-cart-$code');
        _remoteCartChannel!.subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed && !completer.isCompleted) {
            completer.complete();
          }
        });
        await completer.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () => debugPrint('Timeout esperando suscripción al carrito remoto'),
        );
      }

      await _remoteCartChannel!.sendBroadcastMessage(
        event: 'product_scanned',
        payload: {
          'code': product['code'],
          'name': product['name'],
          'price': product['price'],
          'stock': product['stock'],
        },
      );
    } catch (e) {
      debugPrint('No se pudo transmitir el producto al carrito remoto: $e');
    }
  }

  /// Deja de escuchar/usar el canal remoto. Llamar en dispose().
  void stopRemoteCartListen() {
    _remoteCartChannel?.unsubscribe();
    _remoteCartChannel = null;
  }
}
