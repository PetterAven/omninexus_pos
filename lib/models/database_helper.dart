import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  final _supabase = Supabase.instance.client;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('omninexus.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await databaseFactory.getDatabasesPath();
    final path = join(dbPath, filePath);

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: _createDB,
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS users (
                username TEXT PRIMARY KEY,
                password TEXT NOT NULL,
                role TEXT NOT NULL
              )
            ''');
            try {
              await db.insert('users', {
                'username': 'admin',
                'password': 'admin123',
                'role': 'Administrador'
              });
            } catch (_) {}
          }
        },
      ),
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        code TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        stock INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY, 
        total REAL NOT NULL,
        date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sale_details (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_code TEXT NOT NULL,
        product_name TEXT NOT NULL,
        price REAL NOT NULL,
        quantity INTEGER NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE users (
        username TEXT PRIMARY KEY,
        password TEXT NOT NULL,
        role TEXT NOT NULL
      )
    ''');

    // Semilla inicial obligatoria
    await db.insert('users', {
      'username': 'admin',
      'password': 'admin123',
      'role': 'Administrador'
    });
  }

  // ============================================================
  //  MÉTODOS DE PRODUCTOS
  // ============================================================

  Future<List<Map<String, dynamic>>> getProducts() async {
    try {
      final cloudProducts = await _supabase.from('products').select();
      if (cloudProducts.isNotEmpty) {
        final db = await instance.database;
        for (var prod in cloudProducts) {
          await db.insert('products', {
            'code': prod['code'].toString(),
            'name': prod['name'].toString(),
            'price': double.parse(prod['price'].toString()),
            'stock': int.parse(prod['stock'].toString()),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    } catch (e) {
      debugPrint("Modo Offline: Cargando productos locales. $e");
    }

    final db = await instance.database;
    return await db.query('products');
  }

  Future<int> insertProduct(Map<String, dynamic> row) async {
    try {
      await _supabase.from('products').insert({
        'code': row['code'].toString(),
        'name': row['name'].toString(),
        'price': double.parse(row['price'].toString()),
        'stock': int.parse(row['stock'].toString()),
      });
    } catch (e) {
      debugPrint("Offline: Sincronización diferida para inserción.");
    }

    final db = await instance.database;
    return await db.insert('products', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateProduct(Map<String, dynamic> row) async {
    String code = row['code'].toString();
    try {
      await _supabase.from('products').update({
        'name': row['name'].toString(),
        'price': double.parse(row['price'].toString()),
        'stock': int.parse(row['stock'].toString()),
      }).eq('code', code);
    } catch (e) {
      debugPrint("Offline: Sincronización diferida para actualización.");
    }

    final db = await instance.database;
    return await db.update('products', row, where: 'code = ?', whereArgs: [code]);
  }

  Future<int> deleteProduct(String code) async {
    try {
      await _supabase.from('products').delete().eq('code', code);
    } catch (e) {
      debugPrint("Offline: Sincronización diferida para eliminación.");
    }

    final db = await instance.database;
    return await db.delete('products', where: 'code = ?', whereArgs: [code]);
  }

  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    final db = await instance.database;
    if (query.isEmpty) return [];
    return await db.query(
      'products',
      where: 'name LIKE ? OR code LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
    );
  }

  // ============================================================
  //  MÉTODOS DE VENTAS
  // ============================================================

  Future<void> registerSale(double total, List<Map<String, dynamic>> cartItems) async {
    final db = await instance.database;
    String isoDate = DateTime.now().toIso8601String();
    int? finalSaleId;

    // 1. Registrar venta en Supabase (Online)
    try {
      final insertedSale = await _supabase.from('sales').insert({
        'total': total,
        'date': isoDate,
      }).select().single();
      
      finalSaleId = insertedSale['id'] as int;

      if (finalSaleId != null) {
        for (var item in cartItems) {
          await _supabase.from('sale_details').insert({
            'sale_id': finalSaleId,
            'product_code': item['code'].toString(),
            'product_name': item['name'].toString(),
            'price': double.parse(item['price'].toString()),
            'quantity': int.parse(item['quantity'].toString()),
          });

          // Disparador de decremento atómico seguro contra condiciones de carrera
          try {
             await _supabase.rpc('decrement_stock', params: {
               'row_code': item['code'].toString(),
               'quantity_to_sub': int.parse(item['quantity'].toString())
             });
          } catch(_) {}
        }
      }
    } catch (e) {
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

  // ============================================================
  //  MÉTODOS DE USUARIOS (REGLAS DE EMPRESA)
  // ============================================================

  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      final cloudUsers = await _supabase.from('users').select();
      if (cloudUsers.isNotEmpty) {
        final db = await instance.database;
        for (var user in cloudUsers) {
          await db.insert('users', user, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    } catch (_) {}

    final db = await instance.database;
    return await db.query('users');
  }

  Future<Map<String, dynamic>?> loginUser(String username, String password) async {
    try {
      final cloudUser = await _supabase
          .from('users')
          .select()
          .eq('username', username)
          .eq('password', password)
          .maybeSingle();
      
      if (cloudUser != null) return cloudUser;
    } catch (_) {}

    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
    );

    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  /// Registra un usuario aplicando validación de jerarquía empresarial (Regla tipo Walmart)
  Future<int> registerUser({
    required String currentOperatorRole, 
    required String newUsername, 
    required String newPassword, 
    required String newRole,
  }) async {
    // 🛡️ REGLA CRÍTICA DE SEGURIDAD: Solo un Administrador puede crear cuentas en el sistema.
    if (currentOperatorRole != 'Administrador') {
      throw Exception('Acceso Denegado: Tu rol actual ($currentOperatorRole) no tiene autorización para dar de alta cuentas.');
    }

    final Map<String, dynamic> userData = {
      'username': newUsername,
      'password': newPassword,
      'role': newRole,
    };

    // Subir a la nube primero
    try {
      await _supabase.from('users').insert(userData);
    } catch (e) {
      debugPrint("Servidor inaccesible. Creando registro local temporal.");
    }

    final db = await instance.database;
    
    // Verificar si el usuario ya existe localmente para evitar sobreescrituras accidentales
    final List<Map<String, dynamic>> check = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [newUsername],
    );

    if (check.isNotEmpty) {
      throw Exception('El identificador de usuario ya se encuentra registrado.');
    }

    return await db.insert('users', userData, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // 🛡️ Se eliminó el alias createUser(): siempre bypasseaba la validación de rol
  // ("Administrador" a fuerzas) sin importar quién lo llamara. Toda creación de
  // cuentas debe pasar por registerUser() con el rol real de quien tiene la sesión.

  Future<int> deleteUser(String username) async {
    if (username == 'admin') return 0; // El administrador raíz es indestructible
    try {
      await _supabase.from('users').delete().eq('username', username);
    } catch (_) {}
    final db = await instance.database;
    return await db.delete('users', where: 'username = ?', whereArgs: [username]);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}