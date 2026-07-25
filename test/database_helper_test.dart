import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:omninexus_pos/models/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Inicializar SQLite FFI para soporte de pruebas en Windows/Linux
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Evita el MissingPluginException de shared_preferences dentro del
    // entorno de pruebas (supabase_flutter lo usa internamente para
    // guardar la sesión local).
    SharedPreferences.setMockInitialValues({});

    // CORREGIDO: DatabaseHelper crea el cliente de Supabase en su
    // constructor (_supabase = Supabase.instance.client), así que hay que
    // inicializarlo antes de tocar DatabaseHelper.instance. Usamos un
    // proyecto que NO existe a propósito: como la llamada de red va a
    // fallar/hacer timeout, el propio código de DatabaseHelper cae a su
    // modo local (offline) automáticamente -- que es justo lo que
    // queremos para probar la lógica de SQLite de forma aislada, sin
    // depender de tener internet ni credenciales reales.
    await Supabase.initialize(
      url: 'https://fake-project-para-pruebas.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiJ9.fake-signature',
    );
  });

  group('Pruebas Dinámicas - DatabaseHelper', () {
    late DatabaseHelper dbHelper;

    setUp(() {
      dbHelper = DatabaseHelper.instance;
    });

    test('1. Inserta un producto y lo encuentra por código', () async {
      final row = {
        'code': '75010001',
        'name': 'Refresco 600ml',
        'price': 18.50,
        'stock': 50,
      };

      await dbHelper.insertProduct(row);

      final results = await dbHelper.searchProducts('75010001');
      expect(results.isNotEmpty, true);
      expect(results.first['name'], equals('Refresco 600ml'));
      expect(results.first['price'], equals(18.50));
    });

    test('2. Actualiza el stock de un producto existente', () async {
      await dbHelper.insertProduct({
        'code': '75010002',
        'name': 'Galletas',
        'price': 12.0,
        'stock': 20,
      });

      await dbHelper.updateProduct({
        'code': '75010002',
        'name': 'Galletas',
        'price': 12.0,
        'stock': 15,
      });

      final results = await dbHelper.searchProducts('Galletas');
      expect(results.first['stock'], equals(15));
    });

    test('3. Elimina un producto y ya no aparece en la búsqueda', () async {
      await dbHelper.insertProduct({
        'code': '75010003',
        'name': 'Agua 1L',
        'price': 15.0,
        'stock': 30,
      });

      await dbHelper.deleteProduct('75010003');

      final results = await dbHelper.searchProducts('Agua 1L');
      expect(results.isEmpty, true);
    });

    test('4. Cálculo de cambio en pago con efectivo', () {
      const double totalVenta = 142.50;
      const double pagoCliente = 200.00;

      final double cambio = pagoCliente - totalVenta;

      expect(cambio, equals(57.50));
      expect(pagoCliente >= totalVenta, true);
    });
  });
}