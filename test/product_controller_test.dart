import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:omninexus_pos/data/repositories/product_repository.dart';
import 'package:omninexus_pos/domain/entities/product.dart';
import 'package:omninexus_pos/presentation/providers/product_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Mismo patrón que test/database_helper_test.dart: SQLite FFI real +
    // Supabase inicializado contra un proyecto falso para forzar modo
    // offline sin depender de red ni credenciales reales.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://fake-project-para-pruebas.supabase.co',
      publishableKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiJ9.fake-signature',
    );
  });

  // Códigos exclusivos de esta suite para no chocar con los de
  // test/database_helper_test.dart (75010xxx) ni con datos reales.
  const codigoNuevo = '90020001';
  const codigoDuplicado = '90020002';
  const codigoActualizar = '90020003';
  const codigoEliminar = '90020004';

  tearDown(() async {
    // La BD SQLite persiste entre corridas de la suite (igual que en
    // database_helper_test.dart), así que limpiamos lo insertado en
    // cada test para que la siguiente corrida arranque en el mismo
    // estado y "código nuevo" siga siendo realmente nuevo.
    for (final code in [codigoNuevo, codigoDuplicado, codigoActualizar, codigoEliminar]) {
      await ProductRepository.instance.deleteProduct(code);
    }
  });

  test('addProduct con código nuevo devuelve success y aparece en el estado', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(productControllerProvider.future); // espera el build() inicial

    final notifier = container.read(productControllerProvider.notifier);
    final result = await notifier.addProduct(
      const Product(code: codigoNuevo, name: 'Producto Nuevo', price: 25.0, stock: 10),
    );

    expect(result, ProductSaveResult.success);
    final productos = container.read(productControllerProvider).value ?? [];
    expect(productos.any((p) => p.code == codigoNuevo), true);
  });

  test('addProduct con código ya existente en el estado devuelve duplicateCode', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(productControllerProvider.future);

    final notifier = container.read(productControllerProvider.notifier);
    await notifier.addProduct(
      const Product(code: codigoDuplicado, name: 'Original', price: 10.0, stock: 5),
    );
    final result = await notifier.addProduct(
      const Product(code: codigoDuplicado, name: 'Intento duplicado', price: 99.0, stock: 1),
    );

    expect(result, ProductSaveResult.duplicateCode);
    final productos = container.read(productControllerProvider).value ?? [];
    // Debe seguir habiendo una sola fila con ese código, con los datos originales.
    final coincidencias = productos.where((p) => p.code == codigoDuplicado).toList();
    expect(coincidencias.length, 1);
    expect(coincidencias.first.name, 'Original');
  });

  test('updateProduct refleja los cambios en el estado tras refresh', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(productControllerProvider.future);

    final notifier = container.read(productControllerProvider.notifier);
    await notifier.addProduct(
      const Product(code: codigoActualizar, name: 'Antes', price: 10.0, stock: 5),
    );
    await notifier.updateProduct(
      const Product(code: codigoActualizar, name: 'Después', price: 12.5, stock: 3),
    );

    final productos = container.read(productControllerProvider).value ?? [];
    final actualizado = productos.firstWhere((p) => p.code == codigoActualizar);
    expect(actualizado.name, 'Después');
    expect(actualizado.price, 12.5);
    expect(actualizado.stock, 3);
  });

  test('deleteProduct lo quita del estado tras refresh', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(productControllerProvider.future);

    final notifier = container.read(productControllerProvider.notifier);
    await notifier.addProduct(
      const Product(code: codigoEliminar, name: 'A borrar', price: 5.0, stock: 1),
    );
    await notifier.deleteProduct(codigoEliminar);

    final productos = container.read(productControllerProvider).value ?? [];
    expect(productos.any((p) => p.code == codigoEliminar), false);
  });
}