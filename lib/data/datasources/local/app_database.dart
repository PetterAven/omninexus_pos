
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
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
      // 3. sqfliteFfiInit() / databaseFactory también se configuran aquí
      //    como respaldo, aunque ya se inicialicen en main().
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      // 1. Resolvemos una carpeta con permisos de escritura garantizados.
      //    Con fallback automático si la primaria falla (ej. OneDrive bloqueado).
      final appFolder = await _getWritableAppDir();

      // La ruta final: C:\Users\Nombre\Documents\OmniNexusPOS\omninexus.db
      path = join(appFolder.path, filePath);
    } else {
      // Para Android / iOS sigue usando la ruta nativa estándar
      final dbPath = await databaseFactory.getDatabasesPath();
      path = join(dbPath, filePath);
    }

    // 2. Garantizamos que la carpeta padre exista físicamente antes de abrir.
    //    (Redundante si _getWritableAppDir ya la creó, pero es la salvaguarda
    //    explícita que pediste — evita el code 14 sin importar el flujo.)
    final parentDir = Directory(dirname(path));
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }

    debugPrint('📂 Ruta final de la base de datos: $path');

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: createTables,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  /// Intenta usar Documents\OmniNexusPOS. Si no es escribible (permisos,
  /// OneDrive con archivos "solo en la nube", antivirus, etc.), cae a
  /// AppData\Roaming\OmniNexusPOS, que casi nunca tiene ese problema.
  Future<Directory> _getWritableAppDir() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final appFolder = Directory(join(docsDir.path, 'OmniNexusPOS'));
      await appFolder.create(recursive: true);

      // Prueba de escritura real, no solo "exists()"
      final testFile = File(join(appFolder.path, '.write_test'));
      await testFile.writeAsString('ok');
      await testFile.delete();

      return appFolder;
    } catch (e) {
      debugPrint('⚠️ Documents no escribible ($e). Usando AppData como fallback.');
      final supportDir = await getApplicationSupportDirectory();
      final appFolder = Directory(join(supportDir.path, 'OmniNexusPOS'));
      await appFolder.create(recursive: true);
      return appFolder;
    }
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