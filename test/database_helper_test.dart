import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:omninexus_pos/data/datasources/local/app_database.dart';
import 'package:omninexus_pos/data/repositories/product_repository.dart';
import 'package:omninexus_pos/data/repositories/auth_repository.dart';
import 'package:omninexus_pos/domain/entities/product.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Inicialización global de SQLite FFI
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    SharedPreferences.setMockInitialValues({});

    await Supabase.initialize(
      url: 'https://fake-project-para-pruebas.supabase.co',
      publishableKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiJ9.fake-signature',
    );
  });

  setUp(() async {
    // Abrir una instancia completamente limpia en memoria RAM
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: AppDatabase.createTables,
      ),
    );
    // Inyectar en el Singleton de la aplicación
    AppDatabase.instance.setDatabaseForTesting(db);
  });

  tearDown(() async {
    // Cerrar la base de datos y liberar la memoria al terminar cada test
    await AppDatabase.instance.close();
  });

  group('Pruebas Dinámicas - ProductRepository', () {
    late ProductRepository productRepo;

    setUp(() {
      productRepo = ProductRepository.instance;
    });

    test('1. Inserta un producto y lo encuentra por código', () async {
      final product = const Product(
        code: '75010001',
        name: 'Refresco 600ml',
        price: 18.50,
        stock: 50,
      );

      await productRepo.insertProduct(product);

      final results = await productRepo.searchProducts('75010001');
      expect(results.isNotEmpty, true);
      expect(results.first.name, equals('Refresco 600ml'));
      expect(results.first.price, equals(18.50));
    });

    test('2. Actualiza el stock de un producto existente', () async {
      await productRepo.insertProduct(const Product(
        code: '75010002',
        name: 'Galletas',
        price: 12.0,
        stock: 20,
      ));

      await productRepo.updateProduct(const Product(
        code: '75010002',
        name: 'Galletas',
        price: 12.0,
        stock: 15,
      ));

      final results = await productRepo.searchProducts('Galletas');
      expect(results.first.stock, equals(15));
    });

    test('3. Elimina un producto y ya no aparece en la búsqueda', () async {
      await productRepo.insertProduct(const Product(
        code: '75010003',
        name: 'Agua 1L',
        price: 15.0,
        stock: 30,
      ));

      await productRepo.deleteProduct('75010003');

      final results = await productRepo.searchProducts('Agua 1L');
      expect(results.isEmpty, true);
    });

    test('4. Cálculo de cambio en pago con efectivo', () {
      const double totalVenta = 142.50;
      const double pagoCliente = 200.00;

      const double cambio = pagoCliente - totalVenta;

      expect(cambio, equals(57.50));
      expect(pagoCliente >= totalVenta, true);
    });
  });

  group('Pruebas Dinámicas - AuthRepository (bcrypt)', () {
    late AuthRepository authRepo;

    const testUser = 'test_empleado_bcrypt';
    const testPassword = 'clave123';
    const legacyUser = 'test_legacy_plano';
    const legacyPassword = 'plano123';

    setUp(() {
      authRepo = AuthRepository.instance;
    });

    test('5. registerUser guarda la contraseña hasheada, nunca en texto plano', () async {
      await authRepo.registerUser(
        currentOperatorRole: 'Administrador',
        newUsername: testUser,
        newPassword: testPassword,
        newRole: 'Cajero',
      );

      final db = await AppDatabase.instance.database;
      final rows = await db.query('users', where: 'username = ?', whereArgs: [testUser]);

      expect(rows.isNotEmpty, true);
      final storedPassword = rows.first['password'].toString();

      expect(storedPassword, isNot(equals(testPassword)));
      expect(RegExp(r'^\$2[aby]\$\d{2}\$.{53}$').hasMatch(storedPassword), true);
    });

    test('6. loginUser acepta la contraseña correcta y rechaza una incorrecta', () async {
      await authRepo.registerUser(
        currentOperatorRole: 'Administrador',
        newUsername: testUser,
        newPassword: testPassword,
        newRole: 'Cajero',
      );

      final loginOk = await authRepo.loginUser(testUser, testPassword);
      expect(loginOk, isNotNull);
      expect(loginOk!.username, equals(testUser));

      final loginMal = await authRepo.loginUser(testUser, 'contraseña_incorrecta');
      expect(loginMal, isNull);
    });

    test('7. Migración automática: contraseña en texto plano se hashea sola al hacer login', () async {
      final db = await AppDatabase.instance.database;
      await db.insert('users', {
        'username': legacyUser,
        'password': legacyPassword,
        'role': 'Cajero',
      });

      final login = await authRepo.loginUser(legacyUser, legacyPassword);
      expect(login, isNotNull);

      final rows = await db.query('users', where: 'username = ?', whereArgs: [legacyUser]);
      final storedPassword = rows.first['password'].toString();

      expect(storedPassword, isNot(equals(legacyPassword)));
      expect(RegExp(r'^\$2[aby]\$\d{2}\$.{53}$').hasMatch(storedPassword), true);
    });
  });
}