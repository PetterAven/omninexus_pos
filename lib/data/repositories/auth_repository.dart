import 'package:flutter/foundation.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../../core/sync_status.dart';
import '../datasources/local/app_database.dart';

/// Repositorio de autenticación y usuarios: login, alta, baja, y todo
/// el manejo de contraseñas con bcrypt (incluida la migración perezosa
/// de cuentas viejas que aún tenían la contraseña en texto plano).
class AuthRepository {
  static final AuthRepository instance = AuthRepository._init();
  AuthRepository._init();

  final _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      final cloudUsers = await _supabase.from('users').select().timeout(AppConstants.networkTimeout);
      if (cloudUsers.isNotEmpty) {
        final db = await AppDatabase.instance.database;
        for (var user in cloudUsers) {
          await db.insert('users', user, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    } catch (_) {}

    final db = await AppDatabase.instance.database;
    return await db.query('users');
  }

  /// Busca al usuario SOLO por su username (nunca por contraseña en la
  /// consulta) y compara el hash en Dart con BCrypt.checkpw(). Si el
  /// login es correcto pero la contraseña guardada todavía no es un
  /// hash bcrypt (cuentas creadas antes de este cambio), se re-guarda ya
  /// hasheada en ese mismo momento -- migración automática, sin script
  /// aparte ni pedirle a nadie que cambie su contraseña a mano.
  Future<Map<String, dynamic>?> loginUser(String username, String password) async {
    Map<String, dynamic>? user;

    try {
      final cloudUser = await _supabase
          .from('users')
          .select()
          .eq('username', username)
          .maybeSingle()
          .timeout(AppConstants.networkTimeout);
      if (cloudUser != null) user = Map<String, dynamic>.from(cloudUser);
    } catch (_) {}

    if (user == null) {
      final db = await AppDatabase.instance.database;
      final maps = await db.query('users', where: 'username = ?', whereArgs: [username]);
      if (maps.isNotEmpty) user = Map<String, dynamic>.from(maps.first);
    }

    if (user == null) return null;

    final storedPassword = user['password'].toString();
    if (!_verifyPassword(password, storedPassword)) return null;

    if (!_isBcryptHash(storedPassword)) {
      await _rehashPassword(username, password);
    }

    return user;
  }

  bool _isBcryptHash(String value) =>
      value.startsWith(r'$2a$') || value.startsWith(r'$2b$') || value.startsWith(r'$2y$');

  bool _verifyPassword(String plainInput, String stored) {
    if (_isBcryptHash(stored)) {
      try {
        return BCrypt.checkpw(plainInput, stored);
      } catch (_) {
        return false;
      }
    }
    // Compatibilidad con cuentas creadas antes de este cambio (texto plano)
    return plainInput == stored;
  }

  Future<void> _rehashPassword(String username, String plainPassword) async {
    final hashed = BCrypt.hashpw(plainPassword, BCrypt.gensalt());
    try {
      await _supabase.from('users').update({'password': hashed}).eq('username', username).timeout(AppConstants.networkTimeout);
    } catch (_) {}
    final db = await AppDatabase.instance.database;
    await db.update('users', {'password': hashed}, where: 'username = ?', whereArgs: [username]);
  }

  /// Registra un usuario aplicando validación de jerarquía empresarial
  /// (solo un Administrador puede dar de alta cuentas).
  Future<int> registerUser({
    required String currentOperatorRole,
    required String newUsername,
    required String newPassword,
    required String newRole,
  }) async {
    if (currentOperatorRole != 'Administrador') {
      throw Exception('Acceso Denegado: Tu rol actual ($currentOperatorRole) no tiene autorización para dar de alta cuentas.');
    }

    final Map<String, dynamic> userData = {
      'username': newUsername,
      // Se hashea con bcrypt antes de guardarse; nunca se vuelve a
      // escribir una contraseña en texto plano en la BD.
      'password': BCrypt.hashpw(newPassword, BCrypt.gensalt()),
      'role': newRole,
    };

    // Subir a la nube primero
    bool syncedToCloud = true;
    try {
      await _supabase.from('users').insert(userData).timeout(AppConstants.networkTimeout);
    } catch (e) {
      syncedToCloud = false;
      debugPrint("Servidor inaccesible. Creando registro local temporal. $e");
    }

    final db = await AppDatabase.instance.database;

    // Verificar si el usuario ya existe localmente para evitar sobreescrituras accidentales
    final List<Map<String, dynamic>> check = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [newUsername],
    );

    if (check.isNotEmpty) {
      throw Exception('El identificador de usuario ya se encuentra registrado.');
    }

    final result = await db.insert('users', userData, conflictAlgorithm: ConflictAlgorithm.replace);
    SyncStatus.lastSyncOk = syncedToCloud;
    return result;
  }

  Future<int> deleteUser(String username) async {
    if (username == 'admin') return 0; // El administrador raíz es indestructible
    try {
      await _supabase.from('users').delete().eq('username', username).timeout(AppConstants.networkTimeout);
    } catch (_) {}
    final db = await AppDatabase.instance.database;
    return await db.delete('users', where: 'username = ?', whereArgs: [username]);
  }
}
