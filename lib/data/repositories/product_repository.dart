import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../../core/sync_status.dart';
import '../../domain/entities/product.dart';
import '../datasources/local/app_database.dart';

/// Repositorio de productos: toda la lógica que antes vivía mezclada
/// dentro de DatabaseHelper (getProducts, insertProduct, updateProduct,
/// deleteProduct, searchProducts) ahora vive aquí, aislada del resto del
/// código de ventas/usuarios.
///
/// Tipado con la entidad [Product] en vez de Map<String, dynamic>: así
/// los errores de nombre de campo o de tipo se detectan en tiempo de
/// compilación en vez de explotar en producción con un cast fallido.
class ProductRepository {
  static final ProductRepository instance = ProductRepository._init();
  ProductRepository._init();

  final _supabase = Supabase.instance.client;

  Future<List<Product>> getProducts() async {
    try {
      final cloudProducts = await _supabase.from('products').select().timeout(AppConstants.networkTimeout);

      if (cloudProducts.isNotEmpty) {
        final db = await AppDatabase.instance.database;
        for (var prod in cloudProducts) {
          await db.insert('products', Product.fromMap(prod).toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
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
      await _supabase.from('products').insert(product.toMap()).timeout(AppConstants.networkTimeout);
      SyncStatus.lastSyncOk = true;
    } catch (e) {
      SyncStatus.lastSyncOk = false;
      debugPrint("Offline: Sincronización diferida para inserción. $e");
    }

    final db = await AppDatabase.instance.database;
    return await db.insert('products', product.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateProduct(Product product) async {
    try {
      await _supabase
          .from('products')
          .update({'name': product.name, 'price': product.price, 'stock': product.stock})
          .eq('code', product.code)
          .timeout(AppConstants.networkTimeout);
      SyncStatus.lastSyncOk = true;
    } catch (e) {
      SyncStatus.lastSyncOk = false;
      debugPrint("Offline: Sincronización diferida para actualización. $e");
    }

    final db = await AppDatabase.instance.database;
    return await db.update('products', product.toMap(), where: 'code = ?', whereArgs: [product.code]);
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
}
