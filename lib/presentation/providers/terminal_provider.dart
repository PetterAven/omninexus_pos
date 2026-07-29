import 'package:flutter_riverpod/flutter_riverpod.dart';

class TerminalNotifier extends StateNotifier<bool> {
  TerminalNotifier() : super(false); // Por defecto deshabilitado/desconectado

  void setTerminalStatus(bool isConnected) {
    state = isConnected;
  }

  void toggleTerminal() {
    state = !state;
  }
}

final terminalConnectedProvider = StateNotifierProvider<TerminalNotifier, bool>((ref) {
  return TerminalNotifier();
});