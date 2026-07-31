import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/sales_repository.dart';
import '../../domain/entities/cart_item.dart';
import '../../services/ticket_telegram_service.dart';
import '../../services/ticket_pdf_service.dart';
import '../../services/payment_terminal_service.dart';
import 'sales_controller.dart';

class CheckoutResult {
  final List<Map<String, dynamic>> items;
  final double total;
  final double cashReceived;
  final double change;
  final bool isCard;
  final String? linkedUsername;
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

class CheckoutController extends AsyncNotifier<void> {
  CheckoutResult? lastResult;

  @override
  Future<void> build() async {}

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
    state = const AsyncLoading();

    // NUEVO: intenta el cobro real contra la terminal configurada
    // (Clip / Mercado Pago) antes de registrar la venta. Si la terminal
    // rechaza o no hay credenciales, la venta NO se guarda.
    final chargeResult = await PaymentTerminalService.instance.chargeCard(total);
    if (!chargeResult.success) {
      state = AsyncError(chargeResult.message, StackTrace.current);
      return;
    }

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

      ref.invalidate(salesControllerProvider);

      // Solo se manda por Telegram si el cliente vinculó su cuenta con el
      // código de 4 dígitos en ESTA venta. Vincular Telegram es opcional
      // (no todos los clientes quieren instalarlo), así que si nadie se
      // vinculó, simplemente no se manda nada por ahí: el comprobante en
      // PDF/impreso de abajo sigue generándose igual.
      String? telegramError;
      if (linkedChatId != null && linkedChatId.isNotEmpty) {
        telegramError = await TicketTelegramService.instance.sendReceipt(
          ticketItems,
          total,
          cashReceived,
          change,
          isCard: isCard,
          linkedChatId: linkedChatId,
          linkedUsername: linkedUsername,
        );
      }

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

  void reset() {
    lastResult = null;
    state = const AsyncData(null);
  }
}

final checkoutControllerProvider =
    AsyncNotifierProvider<CheckoutController, void>(CheckoutController.new);