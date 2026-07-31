import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../datasources/local/app_database.dart';

/// Repositorio del carrito remoto en tiempo real (Teléfono <-> PC) y del
/// código de sincronización que empareja cada "caja".
///
/// CORREGIDO: el diseño anterior mandaba un evento `product_scanned` por
/// cada producto agregado, pero nada avisaba cuando el carrito se vaciaba
/// (ej. al completar una venta) ni cuando se quitaba un producto -- por
/// eso el carrito remoto "seguía apareciendo" con artículos de la venta
/// anterior. Ahora se transmite el CARRITO COMPLETO (`cart_snapshot`)
/// cada vez que cambia en cualquiera de los dos lados: agregar, quitar,
/// cambiar cantidad, o vaciarlo al cobrar son todos, para efectos de
/// sincronización, "el carrito cambió" -- un solo mecanismo cubre todos
/// los casos en vez de necesitar un evento nuevo por cada acción.
///
/// Usa un canal de "broadcast" de Supabase Realtime: no necesita tablas
/// nuevas ni políticas RLS, solo que el proyecto tenga Realtime activo
/// y "Allow public access" habilitado en Project Settings > Realtime.
class SyncRepository {
  static final SyncRepository instance = SyncRepository._init();
  SyncRepository._init();

  final _supabase = Supabase.instance.client;
  RealtimeChannel? _remoteCartChannel;

  String get _deviceLabel {
    if (Platform.isAndroid || Platform.isIOS) return 'Teléfono';
    return 'PC';
  }

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
    stopRemoteCartListen();
  }

  /// Escucha el carrito completo del otro dispositivo emparejado con el
  /// mismo código (cada vez que cambia, llega entero via
  /// [onCartSnapshotReceived]), y avisa mediante [onPeerConnected] cuando
  /// el otro dispositivo se conecta al mismo canal -- sin importar quién
  /// haya entrado primero, ambos lados reciben la confirmación
  /// ("Teléfono conectado exitosamente" / "PC conectado exitosamente").
  Future<void> listenToRemoteCart(
    void Function(List<Map<String, dynamic>> items) onCartSnapshotReceived, {
    void Function(String deviceLabel)? onPeerConnected,
  }) async {
    stopRemoteCartListen();
    final code = await getSyncCode();
    _remoteCartChannel = _supabase.channel(
      'pos-remote-cart-$code',
      opts: const RealtimeChannelConfig(ack: true),
    );

    _remoteCartChannel!
        .onBroadcast(
          event: 'cart_snapshot',
          callback: (payload) {
            try {
              final rawItems = (payload['items'] as List)
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList();
              onCartSnapshotReceived(rawItems);
            } catch (e) {
              debugPrint('Error procesando snapshot de carrito remoto: $e');
            }
          },
        )
        .onBroadcast(
          event: 'device_online',
          callback: (payload) {
            final label = payload['device']?.toString() ?? 'Dispositivo';
            onPeerConnected?.call(label);
            // Le contestamos para que el otro lado también vea la
            // confirmación, sin importar quién entró primero al canal.
            _remoteCartChannel?.sendBroadcastMessage(
              event: 'device_online_ack',
              payload: {'device': _deviceLabel},
            );
          },
        )
        .onBroadcast(
          event: 'device_online_ack',
          callback: (payload) {
            final label = payload['device']?.toString() ?? 'Dispositivo';
            onPeerConnected?.call(label);
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            _remoteCartChannel?.sendBroadcastMessage(
              event: 'device_online',
              payload: {'device': _deviceLabel},
            );
          } else if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) {
            debugPrint('Error de conexión al canal de sincronización: $error');
          }
        });
  }

  /// Transmite el carrito COMPLETO al otro dispositivo emparejado con el
  /// mismo código. Se llama cada vez que el carrito local cambia
  /// (agregar, quitar, cambiar cantidad, vaciar al cobrar) -- el
  /// dispositivo que recibe reemplaza su carrito entero con este, así
  /// que un carrito vacío aquí también vacía el del otro lado.
  Future<void> sendCartSnapshot(List<Map<String, dynamic>> items) async {
    try {
      await _ensureChannelReady();
      await _remoteCartChannel!.sendBroadcastMessage(
        event: 'cart_snapshot',
        payload: {'items': items},
      );
    } catch (e) {
      debugPrint('No se pudo transmitir el carrito remoto: $e');
    }
  }

  /// Asegura que exista un canal suscrito antes de mandar un mensaje,
  /// por si sendCartSnapshot() se llama antes de que listenToRemoteCart()
  /// haya tenido oportunidad de correr (ej. justo al abrir la pantalla).
  Future<void> _ensureChannelReady() async {
    if (_remoteCartChannel != null) return;

    final code = await getSyncCode();
    final completer = Completer<void>();
    _remoteCartChannel = _supabase.channel(
      'pos-remote-cart-$code',
      opts: const RealtimeChannelConfig(ack: true),
    );
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

  /// Deja de escuchar/usar el canal remoto. Llamar en dispose().
  void stopRemoteCartListen() {
    _remoteCartChannel?.unsubscribe();
    _remoteCartChannel = null;
  }
}