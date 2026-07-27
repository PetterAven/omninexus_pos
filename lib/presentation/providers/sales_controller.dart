import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/sales_repository.dart';
import '../../domain/entities/sale.dart';

/// Estado del corte de caja (lista de ventas del día).
///
/// Extraído de sales_report_dialog.dart: antes `sales`/`granTotal`
/// vivían como variables locales del StatefulBuilder, refrescadas a
/// mano con setDialogState() al presionar el botón de sincronizar.
/// Igual que ProductController/UserController, es
/// AsyncNotifier<List<Sale>> para que loading/error salgan gratis de
/// AsyncValue.
class SalesController extends AsyncNotifier<List<Sale>> {
  @override
  Future<List<Sale>> build() async {
    return SalesRepository.instance.getSales();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => SalesRepository.instance.getSales());
  }
}

final salesControllerProvider =
    AsyncNotifierProvider<SalesController, List<Sale>>(SalesController.new);

/// Derivado: total acumulado del corte de caja. Reemplaza al `granTotal`
/// que antes se recalculaba a mano con un for cada vez que se cargaban
/// o refrescaban las ventas.
final salesTotalProvider = Provider<double>((ref) {
  final salesAsync = ref.watch(salesControllerProvider);
  return salesAsync.maybeWhen(
    data: (sales) {
      double total = 0.0;
      for (final sale in sales) {
        total += sale.total;
      }
      return total;
    },
    orElse: () => 0.0,
  );
});