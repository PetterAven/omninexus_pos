import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/product_repository.dart';
import '../../domain/entities/product.dart';

/// Resultado de intentar guardar (crear) un producto. Igual que
/// CartOperationResult en cart_controller.dart: el controller no conoce
/// BuildContext, así que regresa un resultado y la UI decide qué
/// SnackBar mostrar.
enum ProductSaveResult {
  success,
  duplicateCode,
}

/// Estado del inventario de productos.
///
/// Extraído de `_InventoryScreenState`: antes `_products` + `_isLoading`
/// vivían ahí, con `_refreshInventory()` reasignándolos a mano vía
/// setState() cada vez que se creaba/editaba/eliminaba un producto. Al
/// ser AsyncNotifier<List<Product>>, loading/error salen gratis de
/// AsyncValue -- no hay que cargar un bool _isLoading por separado.
class ProductController extends AsyncNotifier<List<Product>> {
  @override
  Future<List<Product>> build() async {
    return ProductRepository.instance.getProducts();
  }

  /// Reemplaza a la antigua _refreshInventory(). Se expone por separado
  /// de build() porque el botón de refresh y el aviso de "no se pudo
  /// sincronizar con Supabase" (SyncStatus.lastSyncOk) siguen siendo
  /// responsabilidad de la UI, que llama a este método explícitamente.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ProductRepository.instance.getProducts());
  }

  /// Antes vivía en InventoryScreen._showAddProductDialog: se revisaba
  /// a mano si el código ya existía en _products antes de insertar.
  /// Aquí usamos state.value (la lista actual ya cargada) para la misma
  /// validación, sin que la UI tenga que conocer la lista de productos
  /// para hacerla.
  Future<ProductSaveResult> addProduct(Product product) async {
    final current = state.value ?? [];
    final yaExiste = current.any((p) => p.code == product.code);
    if (yaExiste) return ProductSaveResult.duplicateCode;

    await ProductRepository.instance.insertProduct(product);
    await refresh();
    return ProductSaveResult.success;
  }

  Future<void> updateProduct(Product product) async {
    await ProductRepository.instance.updateProduct(product);
    await refresh();
  }

  Future<void> deleteProduct(String code) async {
    await ProductRepository.instance.deleteProduct(code);
    await refresh();
  }
}

final productControllerProvider =
    AsyncNotifierProvider<ProductController, List<Product>>(ProductController.new);