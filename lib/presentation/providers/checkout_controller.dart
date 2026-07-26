import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/sales_repository.dart';
import '../../domain/entities/cart_item.dart';
import '../../services/ticket_telegram_service.dart';
import '../../services/ticket_pdf_service.dart';

/// Lo que la pantalla necesita para pintar el ticket y el snackbar de
/// aviso una vez que el cobro terminó bien. Se guarda aparte del
/// `AsyncValue<void>` del notifier porque ese solo importa para saber
/// si sigue cargando/si hubo error -- la pantalla no necesita "leer"
/// datos de él para reconstruirse en cada frame.
class CheckoutResult {
  final List<Map<String, dynamic>> items;
  final double total;
  final double cashReceived;
  final double change;
  final bool isCard;
  final String? linkedUsername;

  /// Aviso de Telegram (ej. "no se pudo enviar el ticket") que NO debe
  /// marcar el cobro como fallido -- la venta ya quedó registrada y el
  /// PDF ya se generó, solo es una advertencia informativa.
  final String? telegramWarning;

  const CheckoutResult({
    required this.items,
    required this.total,
    required this.cashReceived,
    required this.change,
    required this.isCard,
    this.linkedUsername,
    this.telegramWarning,
  });
}

/// AsyncNotifier<void>: el cobro no "posee" un dato que la UI deba leer
/// en reposo (a diferencia de un carrito o una lista). Solo interesan
/// sus tres estados -- loading mientras se procesa el pago, error si
/// algo truena (monto insuficiente, falla de red al registrar la
/// venta), y data (null) cuando terminó bien.
class CheckoutController extends AsyncNotifier<void> {
  CheckoutResult? lastResult;

  @override
  Future<void> build() async {
    // Sin nada que cargar al inicio: arranca directo en data(null).
  }

  Future<void> payCash({
    required double total,
    required double cashReceived,
    required List<CartItem> cartItems,
    String? linkedChatId,
    String? linkedUsername,
  }) async {
    if (cashReceived < total) {
      state = AsyncError('Monto inferior al total', StackTrace.current);
      return;
    }
    await _process(
      total: total,
      cashReceived: cashReceived,
      cartItems: cartItems,
      isCard: false,
      linkedChatId: linkedChatId,
      linkedUsername: linkedUsername,
    );
  }

  Future<void> payCard({
    required double total,
    required List<CartItem> cartItems,
    String? linkedChatId,
    String? linkedUsername,
  }) async {
    await _process(
      total: total,
      cashReceived: total,
      cartItems: cartItems,
      isCard: true,
      linkedChatId: linkedChatId,
      linkedUsername: linkedUsername,
    );
  }

  Future<void> _process({
    required double total,
    required double cashReceived,
    required List<CartItem> cartItems,
    required bool isCard,
    String? linkedChatId,
    String? linkedUsername,
  }) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final ticketItems = cartItems.map((item) => item.toMap()).toList();
      final change = isCard ? 0.0 : cashReceived - total;

      await SalesRepository.instance.registerSale(total, cartItems);

      final telegramError = await TicketTelegramService.instance.sendReceipt(
        ticketItems,
        total,
        cashReceived,
        change,
        isCard: isCard,
        linkedChatId: linkedChatId,
        linkedUsername: linkedUsername,
      );

      await TicketPdfService.instance.printReceipt(
        ticketItems,
        total,
        cashReceived,
        change,
        isCard: isCard,
        linkedUsername: linkedUsername,
      );

      lastResult = CheckoutResult(
        items: ticketItems,
        total: total,
        cashReceived: cashReceived,
        change: change,
        isCard: isCard,
        linkedUsername: linkedUsername,
        telegramWarning: telegramError,
      );
    });
  }

  /// Limpia el resultado guardado para que un próximo cobro no arrastre
  /// datos del anterior si algo llega a leerlo antes de tiempo.
  void reset() {
    lastResult = null;
    state = const AsyncData(null);
  }
}

final checkoutControllerProvider =
    AsyncNotifierProvider<CheckoutController, void>(CheckoutController.new);