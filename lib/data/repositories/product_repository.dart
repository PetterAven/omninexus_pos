import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../../core/sync_status.dart';
import '../datasources/local/app_database.dart';

/// Repositorio de productos: toda la lógica que antes vivía mezclada
/// dentro de DatabaseHelper (getProducts, insertProduct, updateProduct,
/// deleteProduct, searchProducts) ahora vive aquí, aislada del resto del
/// código de ventas/usuarios.
class ProductRepository {
  static final ProductRepository instance = ProductRepository._init();
  ProductRepository._init();

  final _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getProducts() async {
    try {
      final cloudProducts = await _supabase.from('products').select().timeout(AppConstants.networkTimeout);

      if (cloudProducts.isNotEmpty) {
        final db = await AppDatabase.instance.database;
        for (var prod in cloudProducts) {
          await db.insert('products', {
            'code': prod['code'].toString(),
            'name': prod['name'].toString(),
            'price': double.parse(prod['price'].toString()),
            'stock': int.parse(prod['stock'].toString()),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      SyncStatus.lastSyncOk = true;
    } catch (e) {
      SyncStatus.lastSyncOk = false;
      debugPrint("Modo Offline: Cargando productos locales. $e");
    }

    final db = await AppDatabase.instance.database;
    return await db.query('products');
  }

  Future<int> insertProduct(Map<String, dynamic> row) async {
    try {
      await _supabase.from('products').insert({
        'code': row['code'].toString(),
        'name': row['name'].toString(),
        'price': double.parse(row['price'].toString()),
        'stock': int.parse(row['stock'].toString()),
      }).timeout(AppConstants.networkTimeout);
      SyncStatus.lastSyncOk = true;
    } catch (e) {
      SyncStatus.lastSyncOk = false;
      debugPrint("Offline: Sincronización diferida para inserción. $e");
    }

    final db = await AppDatabase.instance.database;
    return await db.insert('products', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateProduct(Map<String, dynamic> row) async {
    String code = row['code'].toString();
    try {
      await _supabase.from('products').update({
        'name': row['name'].toString(),
        'price': double.parse(row['price'].toString()),
        'stock': int.parse(row['stock'].toString()),
      }).eq('code', code).timeout(AppConstants.networkTimeout);
      SyncStatus.lastSyncOk = true;
    } catch (e) {
      SyncStatus.lastSyncOk = false;
      debugPrint("Offline: Sincronización diferida para actualización. $e");
    }

    final db = await AppDatabase.instance.database;
    return await db.update('products', row, where: 'code = ?', whereArgs: [code]);
  }

  Future<int> deleteProduct(String code) async {
    try {
      await _supabase.from('products').delete().eq('code', code).timeout(AppConstants.networkTimeout);
      SyncStatus.lastSyncOk = true;
    } catch (e) {
      SyncStatus.lastSyncOk = false;
      debugPrint("Offline: Sincronización diferida para eliminación. $e");
    }

    final db = await AppDatabase.instance.database;
    return await db.delete('products', where: 'code = ?', whereArgs: [code]);
  }

  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    final db = await AppDatabase.instance.database;
    if (query.isEmpty) return [];
    return await db.query(
      'products',
      where: 'name LIKE ? OR code LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
    );
  }
}
