import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../../core/sync_status.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_detail.dart';
import '../datasources/local/app_database.dart';

/// Repositorio de ventas: registrar una venta (encabezado + detalle +
/// descuento de stock) y leer el historial/corte de caja, jalando
/// primero de Supabase para que se vea igual en todos los dispositivos.
class SalesRepository {
  static final SalesRepository instance = SalesRepository._init();
  SalesRepository._init();

  final _supabase = Supabase.instance.client;

  Future<Sale> registerSale(double total, List<CartItem> cartItems) async {
    final db = await AppDatabase.instance.database;
    final String isoDate = DateTime.now().toIso8601String();
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

      for (final item in cartItems) {
        final detail = SaleDetail(
          saleId: finalSaleId,
          productCode: item.product.code,
          productName: item.product.name,
          price: item.product.price,
          quantity: item.quantity,
        );

        await _supabase.from('sale_details').insert(detail.toInsertMap()).timeout(AppConstants.networkTimeout);

        // Disparador de decremento atómico seguro contra condiciones de carrera
        try {
          await _supabase.rpc('decrement_stock', params: {
            'row_code': item.product.code,
            'quantity_to_sub': item.quantity,
          }).timeout(AppConstants.networkTimeout);
        } catch (_) {}
      }
      SyncStatus.lastSyncOk = true;
    } catch (e) {
      SyncStatus.lastSyncOk = false;
      debugPrint("Venta guardada en búfer local (Pendiente de sincronizar): $e");
    }

    // 2. Registrar venta en SQLite Local de manera transaccional
    final int localSaleId = await db.transaction<int>((txn) async {
      final int insertedId = await txn.insert(
        'sales',
        {
          if (finalSaleId != null) 'id': finalSaleId,
          'total': total,
          'date': isoDate,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final int saleId = finalSaleId ?? insertedId;

      for (final item in cartItems) {
        final detail = SaleDetail(
          saleId: saleId,
          productCode: item.product.code,
          productName: item.product.name,
          price: item.product.price,
          quantity: item.quantity,
        );
        await txn.insert('sale_details', detail.toInsertMap());

        // Actualización directa del inventario local
        await txn.execute(
          'UPDATE products SET stock = stock - ? WHERE code = ?',
          [item.quantity, item.product.code],
        );
      }

      return saleId;
    });

    return Sale(id: finalSaleId ?? localSaleId, total: total, date: isoDate);
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
        for (final raw in cloudDetails) {
          final detail = SaleDetail.fromMap(Map<String, dynamic>.from(raw));
          batch.insert('sale_details', detail.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
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
  Future<List<SaleDetail>> getSaleDetails(int saleId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('sale_details', where: 'sale_id = ?', whereArgs: [saleId]);
    return rows.map(SaleDetail.fromMap).toList();
  }

  Future<List<Sale>> getSales() async {
    try {
      final cloudSales = await _supabase
          .from('sales')
          .select()
          .order('id', ascending: false)
          .timeout(AppConstants.networkTimeout);

      if (cloudSales.isNotEmpty) {
        final db = await AppDatabase.instance.database;
        for (final raw in cloudSales) {
          final sale = Sale.fromMap(Map<String, dynamic>.from(raw));
          await db.insert('sales', sale.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
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
    final rows = await db.query('sales', orderBy: 'id DESC');
    return rows.map(Sale.fromMap).toList();
  }
}