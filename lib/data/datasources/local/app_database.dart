import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart'; // 👈 IMPORTANTE
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:bcrypt/bcrypt.dart';

/// Datasource LOCAL: solo se encarga de abrir, crear y migrar la base de
/// datos SQLite.
class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('omninexus.db');
    return _database!;
  }

  /// Permite inyectar una instancia personalizada (ej. BD en RAM para pruebas).
  @visibleForTesting
  void setDatabaseForTesting(Database db) {
    _database = db;
  }

  Future<Database> _initDB(String filePath) async {
    String path;

    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      // 1. Obtenemos la carpeta "Documentos" del usuario actual
      final docsDir = await getApplicationDocumentsDirectory();

      // 2. Creamos una carpeta propia para el punto de venta
      final appFolder = Directory(join(docsDir.path, 'OmniNexusPOS'));
      if (!await appFolder.exists()) {
        await appFolder.create(recursive: true);
      }

      // 3. La ruta final será: C:\Users\Nombre\Documents\OmniNexusPOS\omninexus.db
      path = join(appFolder.path, filePath);
    } else {
      // Para Android / iOS sigue usando la ruta nativa estándar
      final dbPath = await databaseFactory.getDatabasesPath();
      path = join(dbPath, filePath);
    }

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: createTables,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
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
          'password': BCrypt.hashpw('admin123', BCrypt.gensalt()),
          'role': 'Administrador',
        });
      } catch (_) {}
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    }
  }

  /// Esquema de tablas estático expuesto para poder reutilizarse en los tests
  static Future<void> createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        code TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        stock INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales (
        id INTEGER PRIMARY KEY,
        total REAL NOT NULL,
        date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_details (
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
      CREATE TABLE IF NOT EXISTS users (
        username TEXT PRIMARY KEY,
        password TEXT NOT NULL,
        role TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Semilla inicial obligatoria
    try {
      await db.insert('users', {
        'username': 'admin',
        'password': BCrypt.hashpw('admin123', BCrypt.gensalt()),
        'role': 'Administrador',
      });
    } catch (_) {}
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}