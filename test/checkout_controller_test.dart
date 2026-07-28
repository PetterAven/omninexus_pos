import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninexus_pos/domain/entities/cart_item.dart';
import 'package:omninexus_pos/presentation/providers/checkout_controller.dart';

void main() {
  // OPCIÓN A: solo se testea la lógica pura y segura de CheckoutController
  // -- la validación de payCash antes de _process(). El camino feliz
  // completo (SalesRepository.registerSale + TicketTelegramService +
  // TicketPdfService) queda fuera a propósito: TicketPdfService.printReceipt
  // usa un plugin nativo de impresión que no tiene canal de plataforma en
  // `flutter test` (tronaría con MissingPluginException), y
  // TicketTelegramService.sendReceipt haría una llamada HTTP real a
  // Telegram. Cubrir ese camino completo requeriría la Opción B
  // (inyectar esos servicios por constructor + mocktail).

  late ProviderContainer container;

  setUp(() async {
    container = ProviderContainer();
    addTearDown(container.dispose);
    // CLAVE: build() es async (aunque su cuerpo esté vacío) y su
    // finalización llega como un microtask. Si no se espera aquí, ese
    // microtask puede resolverse DESPUÉS de que payCash() ya puso
    // `state = AsyncError(...)` de forma síncrona, y al resolverse
    // sobreescribe el estado de vuelta a AsyncData(null) -- por eso los
    // tests de abajo veían AsyncData en vez de AsyncError. Esperar el
    // .future del provider deja el estado inicial ya asentado antes de
    // que cada test empiece a mutarlo.
    await container.read(checkoutControllerProvider.future);
  });

  const List<CartItem> carritoVacio = [];

  test('payCash con cashReceived menor al total deja el estado en AsyncError', () async {
    final notifier = container.read(checkoutControllerProvider.notifier);

    await notifier.payCash(
      total: 100.0,
      cashReceived: 50.0,
      cartItems: carritoVacio,
    );

    final state = container.read(checkoutControllerProvider);
    expect(state, isA<AsyncError>());
    expect(state.hasError, true);
    expect(state.error.toString(), contains('Monto inferior al total'));
  });

  test('payCash con cashReceived insuficiente no llega a _process() (lastResult sigue null)', () async {
    final notifier = container.read(checkoutControllerProvider.notifier);

    await notifier.payCash(
      total: 100.0,
      cashReceived: 99.99,
      cartItems: carritoVacio,
    );

    // Si _process() se hubiera ejecutado, lastResult ya no sería null
    // (o el test habría tronado al intentar registrar la venta / imprimir
    // el ticket). Que siga null confirma que la validación cortó antes.
    expect(notifier.lastResult, isNull);
  });

  // NOTA (Opción A): a propósito NO hay un test con `cashReceived >=
  // total`, porque en cuanto la validación pasa, payCash() sigue de
  // largo hacia _process() -- que llama a SalesRepository.registerSale
  // (SQLite/Supabase reales), TicketTelegramService.sendReceipt (HTTP
  // real a Telegram) y TicketPdfService.printReceipt (plugin nativo sin
  // canal de plataforma en `flutter test`, tronaría con
  // MissingPluginException). Ese camino feliz completo solo se puede
  // cubrir con la Opción B (inyección de esos servicios + mocktail).

  test('reset() limpia lastResult y deja el estado en AsyncData(null)', () async {
    final notifier = container.read(checkoutControllerProvider.notifier);

    await notifier.payCash(total: 100.0, cashReceived: 50.0, cartItems: carritoVacio);
    expect(container.read(checkoutControllerProvider), isA<AsyncError>());

    notifier.reset();

    expect(notifier.lastResult, isNull);
    expect(container.read(checkoutControllerProvider), const AsyncData<void>(null));
  });
}