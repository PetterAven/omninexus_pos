import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../../core/sync_status.dart';
import '../datasources/local/app_database.dart';

/// Repositorio de ventas: registrar una venta (encabezado + detalle +
/// descuento de stock) y leer el historial/corte de caja, jalando
/// primero de Supabase para que se vea igual en todos los dispositivos.
class SalesRepository {
  static final SalesRepository instance = SalesRepository._init();
  SalesRepository._init();

  final _supabase = Supabase.instance.client;

  Future<void> registerSale(double total, List<Map<String, dynamic>> cartItems) async {
    final db = await AppDatabase.instance.database;
    String isoDate = DateTime.now().toIso8601String();
    int? finalSaleId;

    // 1. Registrar venta en Supabase (Online)
    try {
      final insertedSale = await _supabase
          .from('sales')
          .insert({
            'total': total,
            'date': isoDate,
          })
          .select()
          .single()
          .timeout(AppConstants.networkTimeout);

      finalSaleId = insertedSale['id'] as int;

      for (var item in cartItems) {
        await _supabase.from('sale_details').insert({
          'sale_id': finalSaleId,
          'product_code': item['code'].toString(),
          'product_name': item['name'].toString(),
          'price': double.parse(item['price'].toString()),
          'quantity': int.parse(item['quantity'].toString()),
        }).timeout(AppConstants.networkTimeout);

        // Disparador de decremento atómico seguro contra condiciones de carrera
        try {
          await _supabase.rpc('decrement_stock', params: {
            'row_code': item['code'].toString(),
            'quantity_to_sub': int.parse(item['quantity'].toString())
          }).timeout(AppConstants.networkTimeout);
        } catch (_) {}
      }
      SyncStatus.lastSyncOk = true;
    } catch (e) {
      SyncStatus.lastSyncOk = false;
      debugPrint("Venta guardada en búfer local (Pendiente de sincronizar): $e");
    }

    // 2. Registrar venta en SQLite Local de manera transaccional
    await db.transaction((txn) async {
      int localSaleId = await txn.insert('sales', {
        if (finalSaleId != null) 'id': finalSaleId,
        'total': total,
        'date': isoDate,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      for (var item in cartItems) {
        await txn.insert('sale_details', {
          'sale_id': finalSaleId ?? localSaleId,
          'product_code': item['code'],
          'product_name': item['name'],
          'price': item['price'],
          'quantity': item['quantity'],
        });

        // Actualización directa del inventario local
        await txn.execute(
          'UPDATE products SET stock = stock - ? WHERE code = ?',
          [item['quantity'], item['code']],
        );
      }
    });
  }

  /// Antes 'sale_details' nunca se volvía a bajar de Supabase -- solo se
  /// insertaba al hacer la venta. Por eso el corte de caja solo mostraba
  /// el TOTAL de cada ticket, nunca qué productos lo componían. Igual
  /// que getProducts()/getSales(), jalamos todos los detalles de
  /// Supabase y los guardamos en local antes de leer.
  Future<void> _syncSaleDetails() async {
    try {
      final cloudDetails = await _supabase.from('sale_details').select().timeout(AppConstants.networkTimeout);

      if (cloudDetails.isNotEmpty) {
        final db = await AppDatabase.instance.database;
        final batch = db.batch();
        for (var detail in cloudDetails) {
          batch.insert(
            'sale_details',
            {
              'id': detail['id'],
              'sale_id': detail['sale_id'],
              'product_code': detail['product_code'].toString(),
              'product_name': detail['product_name'].toString(),
              'price': double.parse(detail['price'].toString()),
              'quantity': int.parse(detail['quantity'].toString()),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      }
    } catch (e) {
      debugPrint('Modo Offline: no se pudo sincronizar el detalle de ventas. $e');
    }
  }

  /// Desglose de productos de una venta específica, para mostrar en el
  /// corte de caja/historial. Lee de local -- que ya se mantiene al día
  /// gracias a _syncSaleDetails() llamado desde getSales().
  Future<List<Map<String, dynamic>>> getSaleDetails(int saleId) async {
    final db = await AppDatabase.instance.database;
    return await db.query('sale_details', where: 'sale_id = ?', whereArgs: [saleId]);
  }

  Future<List<Map<String, dynamic>>> getSales() async {
    try {
      final cloudSales = await _supabase
          .from('sales')
          .select()
          .order('id', ascending: false)
          .timeout(AppConstants.networkTimeout);

      if (cloudSales.isNotEmpty) {
        final db = await AppDatabase.instance.database;
        for (var sale in cloudSales) {
          await db.insert('sales', {
            'id': sale['id'],
            'total': double.parse(sale['total'].toString()),
            'date': sale['date'].toString(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      SyncStatus.lastSyncOk = true;
    } catch (e) {
      SyncStatus.lastSyncOk = false;
      debugPrint('Modo Offline: mostrando ventas guardadas en este equipo. $e');
    }

    // Mantenemos el detalle de cada venta sincronizado también.
    await _syncSaleDetails();

    final db = await AppDatabase.instance.database;
    return await db.query('sales', orderBy: 'id DESC');
  }
}
