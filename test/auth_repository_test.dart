import 'package:flutter_test/flutter_test.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE users (
            id TEXT PRIMARY KEY,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            role TEXT NOT NULL
          )
        ''');
      },
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Pruebas de Autenticación y Bcrypt', () {
    test('1. Insertar usuario con hash Bcrypt', () async {
      const plainPassword = 'SecretPassword123';
      final hashedPassword = BCrypt.hashpw(plainPassword, BCrypt.gensalt());

      await db.insert('users', {
        'id': 'usr-001',
        'username': 'admin_pos',
        'password_hash': hashedPassword,
        'role': 'Administrador',
      });

      final result = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: ['admin_pos'],
      );

      expect(result.length, equals(1));
      expect(result.first['username'], equals('admin_pos'));
      expect(
        BCrypt.checkpw(plainPassword, result.first['password_hash'] as String),
        isTrue,
      );
    });

    test('2. Rechazar contraseña incorrecta', () async {
      const plainPassword = 'CorrectPassword';
      final hashedPassword = BCrypt.hashpw(plainPassword, BCrypt.gensalt());

      await db.insert('users', {
        'id': 'usr-002',
        'username': 'cajero1',
        'password_hash': hashedPassword,
        'role': 'Cajero',
      });

      final user = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: ['cajero1'],
      );

      final storedHash = user.first['password_hash'] as String;
      final isMatch = BCrypt.checkpw('WrongPassword', storedHash);

      expect(isMatch, isFalse);
    });

    test('3. Estructura y formato del Hash de Bcrypt', () async {
      const password = 'TestStringForHashFormat';
      final hash = BCrypt.hashpw(password, BCrypt.gensalt());

      final bcryptRegex = RegExp(r'^\$2[aby]\$\d{2}\$.{53}$');
      expect(bcryptRegex.hasMatch(hash), isTrue);
    });

    test('4. Migración de texto plano a Bcrypt tras Login', () async {
      const legacyPassword = 'LegacyPlainTextPassword';

      await db.insert('users', {
        'id': 'usr-legacy',
        'username': 'old_user',
        'password_hash': legacyPassword,
        'role': 'Cajero',
      });

      final userRecords = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: ['old_user'],
      );

      final storedValue = userRecords.first['password_hash'] as String;

      if (!storedValue.startsWith('\$2')) {
        if (storedValue == legacyPassword) {
          final newHash = BCrypt.hashpw(legacyPassword, BCrypt.gensalt());
          await db.update(
            'users',
            {'password_hash': newHash},
            where: 'id = ?',
            whereArgs: ['usr-legacy'],
          );
        }
      }

      final updatedRecords = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: ['old_user'],
      );

      final updatedHash = updatedRecords.first['password_hash'] as String;
      expect(updatedHash.startsWith('\$2'), isTrue);
      expect(BCrypt.checkpw(legacyPassword, updatedHash), isTrue);
    });
  });
}