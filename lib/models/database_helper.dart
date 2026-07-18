import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('omninexus.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // Inicialización para entornos de escritorio (Windows / Linux)
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await databaseFactory.getDatabasesPath();
    final path = join(dbPath, filePath);

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2, // Subimos a versión 2 para activar el onUpgrade si ya existía la BD
        onCreate: _createDB,
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            // Si el usuario ya tenía la app instalada, creamos la tabla faltante de forma segura
            await db.execute('''
              CREATE TABLE IF NOT EXISTS users (
                username TEXT PRIMARY KEY,
                password TEXT NOT NULL,
                role TEXT NOT NULL
              )
            ''');
            
            // Insertamos el administrador por defecto de respaldo
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
    // Tabla de Productos
    await db.execute('''
      CREATE TABLE products (
        code TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        stock INTEGER NOT NULL
      )
    ''');

    // Tabla de Ventas (Cabecera)
    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        total REAL NOT NULL,
        date TEXT NOT NULL
      )
    ''');

    // Tabla de Detalles de Ventas (Walmart Style / Tickets)
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

    // Tabla de Usuarios
    await db.execute('''
      CREATE TABLE users (
        username TEXT PRIMARY KEY,
        password TEXT NOT NULL,
        role TEXT NOT NULL
      )
    ''');

    // Insertar un usuario Administrador por defecto al crear la base de datos desde cero
    await db.insert('users', {
      'username': 'admin',
      'password': 'admin123',
      'role': 'Administrador'
    });
  }

  // ==========================================
  //          MÉTODOS DE PRODUCTOS
  // ==========================================

  Future<List<Map<String, dynamic>>> getProducts() async {
    final db = await instance.database;
    return await db.query('products');
  }

  Future<int> insertProduct(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('products', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateProduct(Map<String, dynamic> row) async {
    final db = await instance.database;
    String code = row['code'];
    return await db.update('products', row, where: 'code = ?', whereArgs: [code]);
  }

  Future<int> deleteProduct(String code) async {
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

  // ==========================================
  //          MÉTODOS DE VENTAS Y TICKETS
  // ==========================================

  Future<void> registerSale(double total, List<Map<String, dynamic>> cartItems) async {
    final db = await instance.database;

    await db.transaction((txn) async {
      // 1. Insertar la cabecera de la venta
      int saleId = await txn.insert('sales', {
        'total': total,
        'date': DateTime.now().toIso8601String(),
      });

      // 2. Procesar cada artículo del carrito
      for (var item in cartItems) {
        // Guardar el detalle de la venta para el historial/ticket
        await txn.insert('sale_details', {
          'sale_id': saleId,
          'product_code': item['code'],
          'product_name': item['name'],
          'price': item['price'],
          'quantity': item['quantity'],
        });

        // Descontar del inventario actual de productos
        await txn.execute(
          'UPDATE products SET stock = stock - ? WHERE code = ?',
          [item['quantity'], item['code']],
        );
      }
    });
  }

  // ==========================================
  //          MÉTODOS DE USUARIOS
  // ==========================================

  // Obtener la lista completa de usuarios para el panel de administración
  Future<List<Map<String, dynamic>>> getUsers() async {
    final db = await instance.database;
    return await db.query('users');
  }

  // Validar credenciales al iniciar sesión
  Future<Map<String, dynamic>?> loginUser(String username, String password) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
    );

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  // Registrar un nuevo usuario de forma segura
  Future<int> registerUser(String username, String password, String role) async {
    final db = await instance.database;
    
    // Primero verificamos manualmente si el usuario de verdad existe
    final List<Map<String, dynamic>> check = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );

    if (check.isNotEmpty) {
      // Si arrojamos una excepción controlada, nuestro Catch de la UI sabrá qué responder
      throw Exception('El usuario ya se encuentra registrado.');
    }

    return await db.insert('users', {
      'username': username,
      'password': password,
      'role': role,
    });
  }

  // Método puente compatible con 'login_screen.dart'
  Future<int> createUser(String username, String password, String role) async {
    return await registerUser(username, password, role);
  }

  // Eliminar un usuario del sistema
  Future<int> deleteUser(String username) async {
    final db = await instance.database;
    // Evitar que se elimine el administrador por defecto mediante código
    if (username == 'admin') return 0;
    return await db.delete('users', where: 'username = ?', whereArgs: [username]);
  }

  // Cerrar la base de datos de manera limpia
  Future close() async {
    final db = await instance.database;
    db.close();
  }
}