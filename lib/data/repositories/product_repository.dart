import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../../core/sync_status.dart';
import '../../domain/entities/product.dart';
import '../datasources/local/app_database.dart';

class ProductRepository {
  static final ProductRepository instance = ProductRepository._init();
  ProductRepository._init();

  final _supabase = Supabase.instance.client;

  Future<List<Product>> getProducts() async {
    try {
      final cloudProducts = await _supabase
          .from('products')
          .select()
          .timeout(AppConstants.networkTimeout);

      if (cloudProducts.isNotEmpty) {
        final db = await AppDatabase.instance.database;
        for (var prod in cloudProducts) {
          await db.insert(
            'products',
            Product.fromMap(prod).toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      SyncStatus.lastSyncOk = true;
    } catch (e) {
      SyncStatus.lastSyncOk = false;
      debugPrint("Modo Offline: Cargando productos locales. $e");
    }

    final db = await AppDatabase.instance.database;
    final rows = await db.query('products');
    return rows.map(Product.fromMap).toList();
  }

  Future<int> insertProduct(Product product) async {
    try {
      await _supabase
          .from('products')
          .insert(product.toMap())
          .timeout(AppConstants.networkTimeout);
      SyncStatus.lastSyncOk = true;
    } catch (e) {
      SyncStatus.lastSyncOk = false;
      debugPrint("Offline: Sincronización diferida para inserción. $e");
    }

    final db = await AppDatabase.instance.database;
    return await db.insert(
      'products',
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateProduct(Product product) async {
    // 1. Guardar primero en SQLite Local para garantizar persistencia inmediata
    final db = await AppDatabase.instance.database;
    final localRows = await db.update(
      'products',
      product.toMap(),
      where: 'code = ?',
      whereArgs: [product.code],
    );

    // 2. Intentar sincronizar con Supabase Cloud
    try {
      await _supabase
          .from('products')
          .update(product.toMap()) // Mapeo consistente
          .eq('code', product.code)
          .timeout(AppConstants.networkTimeout);
      SyncStatus.lastSyncOk = true;
    } catch (e) {
      SyncStatus.lastSyncOk = false;
      debugPrint("Offline: Sincronización diferida para actualización. $e");
    }

    return localRows;
  }

  Future<int> deleteProduct(String code) async {
    final db = await AppDatabase.instance.database;
    final result = await db.delete('products', where: 'code = ?', whereArgs: [code]);

    try {
      await _supabase
          .from('products')
          .delete()
          .eq('code', code)
          .timeout(AppConstants.networkTimeout);
      SyncStatus.lastSyncOk = true;
    } catch (e) {
      SyncStatus.lastSyncOk = false;
      debugPrint("Offline: Sincronización diferida para eliminación. $e");
    }

    return result;
  }

  Future<List<Product>> searchProducts(String query) async {
    final db = await AppDatabase.instance.database;
    if (query.isEmpty) return [];
    final rows = await db.query(
      'products',
      where: 'name LIKE ? OR code LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
    );
    return rows.map(Product.fromMap).toList();
  }

  Future<void> bulkUpsertProducts(List<Product> products) async {
    try {
      await _supabase
          .from('products')
          .upsert(products.map((p) => p.toMap()).toList())
          .timeout(AppConstants.networkTimeout);
      SyncStatus.lastSyncOk = true;
    } catch (e) {
      SyncStatus.lastSyncOk = false;
      debugPrint("Offline: Sincronización diferida para importación masiva. $e");
    }

    final db = await AppDatabase.instance.database;
    final batch = db.batch();
    for (final product in products) {
      batch.insert(
        'products',
        product.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }
}