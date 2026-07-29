import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PaymentProvider { clip, mercadoPago }

class PaymentTerminalCredentials {
  final String apiKey;
  final String terminalId;

  const PaymentTerminalCredentials({required this.apiKey, required this.terminalId});

  static const empty = PaymentTerminalCredentials(apiKey: '', terminalId: '');

  bool get isComplete => apiKey.trim().isNotEmpty && terminalId.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {'apiKey': apiKey, 'terminalId': terminalId};

  factory PaymentTerminalCredentials.fromJson(Map<String, dynamic> json) => PaymentTerminalCredentials(
        apiKey: json['apiKey']?.toString() ?? '',
        terminalId: json['terminalId']?.toString() ?? '',
      );
}

class PaymentChargeResult {
  final bool success;
  final String message;
  final String? authorizationCode;

  const PaymentChargeResult({required this.success, required this.message, this.authorizationCode});
}

abstract class PaymentTerminalGateway {
  Future<PaymentChargeResult> charge(double amount);
}

/// CASCARÓN: aquí va el SDK real de Clip (Clip Checkout / Clip SDK)
/// cuando se contrate la cuenta. Por ahora simula el tiempo de espera de
/// la terminal física y siempre "aprueba", para poder probar todo el
/// flujo de ticket/Telegram/PDF sin depender del hardware.
class ClipTerminalGateway implements PaymentTerminalGateway {
  final PaymentTerminalCredentials credentials;
  ClipTerminalGateway(this.credentials);

  @override
  Future<PaymentChargeResult> charge(double amount) async {
    await Future.delayed(const Duration(seconds: 2));
    return PaymentChargeResult(
      success: true,
      message: 'Pago simulado con Clip (cascarón, sin SDK real conectado todavía).',
      authorizationCode: 'CLIP-SIM-${DateTime.now().millisecondsSinceEpoch}',
    );
  }
}

/// CASCARÓN: aquí va la integración real con Mercado Pago Point (crear
/// una intención de pago y sondear el estado de la terminal) cuando se
/// tenga la cuenta y el device_id reales.
class MercadoPagoTerminalGateway implements PaymentTerminalGateway {
  final PaymentTerminalCredentials credentials;
  MercadoPagoTerminalGateway(this.credentials);

  @override
  Future<PaymentChargeResult> charge(double amount) async {
    await Future.delayed(const Duration(seconds: 2));
    return PaymentChargeResult(
      success: true,
      message: 'Pago simulado con Mercado Pago Point (cascarón, sin SDK real conectado todavía).',
      authorizationCode: 'MP-SIM-${DateTime.now().millisecondsSinceEpoch}',
    );
  }
}

class PaymentTerminalService {
  PaymentTerminalService._();
  static final PaymentTerminalService instance = PaymentTerminalService._();

  static const _kActiveProviderKey = 'payment_active_provider';
  static const _kClipCredentialsKey = 'payment_clip_credentials';
  static const _kMercadoPagoCredentialsKey = 'payment_mp_credentials';

  Future<PaymentProvider?> getActiveProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kActiveProviderKey);
    if (raw == 'clip') return PaymentProvider.clip;
    if (raw == 'mercadoPago') return PaymentProvider.mercadoPago;
    return null;
  }

  Future<void> setActiveProvider(PaymentProvider? provider) async {
    final prefs = await SharedPreferences.getInstance();
    if (provider == null) {
      await prefs.remove(_kActiveProviderKey);
    } else {
      await prefs.setString(_kActiveProviderKey, provider.name);
    }
  }

  Future<PaymentTerminalCredentials> getCredentials(PaymentProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    final key = provider == PaymentProvider.clip ? _kClipCredentialsKey : _kMercadoPagoCredentialsKey;
    final raw = prefs.getString(key);
    if (raw == null) return PaymentTerminalCredentials.empty;
    return PaymentTerminalCredentials.fromJson(jsonDecode(raw));
  }

  Future<void> saveCredentials(PaymentProvider provider, PaymentTerminalCredentials credentials) async {
    final prefs = await SharedPreferences.getInstance();
    final key = provider == PaymentProvider.clip ? _kClipCredentialsKey : _kMercadoPagoCredentialsKey;
    await prefs.setString(key, jsonEncode(credentials.toJson()));
  }

  /// El botón de "Cobrar con Tarjeta" solo se habilita si hay un proveedor
  /// activo Y sus credenciales están completas.
  Future<bool> hasValidCredentials() async {
    final provider = await getActiveProvider();
    if (provider == null) return false;
    final creds = await getCredentials(provider);
    return creds.isComplete;
  }

  Future<PaymentChargeResult> chargeCard(double amount) async {
    final provider = await getActiveProvider();
    if (provider == null) {
      return const PaymentChargeResult(success: false, message: 'No hay una terminal de pago configurada.');
    }
    final creds = await getCredentials(provider);
    if (!creds.isComplete) {
      return const PaymentChargeResult(success: false, message: 'Faltan credenciales de la terminal de pago.');
    }

    final gateway = provider == PaymentProvider.clip
        ? ClipTerminalGateway(creds)
        : MercadoPagoTerminalGateway(creds);

    return gateway.charge(amount);
  }
}

/// Se usa en payment_panel.dart para habilitar/deshabilitar el botón de
/// tarjeta reactivamente. autoDispose para que se reconsulte cada vez
/// que se vuelve a la pantalla de cobro (por ejemplo tras guardar ajustes).
final paymentTerminalReadyProvider = FutureProvider.autoDispose<bool>((ref) {
  return PaymentTerminalService.instance.hasValidCredentials();
});