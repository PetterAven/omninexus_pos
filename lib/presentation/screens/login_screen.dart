import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_controller.dart';
import 'sales_terminal_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  // CORREGIDO: FocusNodes para poder controlar a dónde salta el cursor
  // al presionar Enter, y para poder disparar el login con el teclado.
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _login() {
    final authState = ref.read(authControllerProvider);
    if (authState.isLoading) return; // evita doble submit si mantienen Enter presionado

    final user = _usernameController.text.trim();
    final pass = _passwordController.text;

    if (user.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor llena todos los campos')),
      );
      return;
    }

    ref.read(authControllerProvider.notifier).login(user, pass);
  }

  // 🛡️ El auto-registro público fue retirado por seguridad (Regla tipo Walmart):
  // ningún usuario anónimo puede crear cuentas, y mucho menos elegir su propio rol.
  // Las cuentas ahora solo se crean desde "Gestión de Personal", dentro del sistema,
  // por un usuario que ya inició sesión con rol Administrador.

  @override
  Widget build(BuildContext context) {
    // Reacciona UNA sola vez cuando el login pasa de loading a
    // data(AppUser) con éxito, y navega a la Terminal de Ventas. El
    // login incorrecto llega como AsyncError y se muestra en el
    // ref.watch de abajo (isLoading/errorText), no aquí.
    ref.listen(authControllerProvider, (previous, next) {
      final wasLoading = previous?.isLoading ?? false;
      if (wasLoading && next.hasValue && next.value != null) {
        _usernameController.clear();
        _passwordController.clear();
        Navigator.push(
          context,
          MaterialPageRoute(
            // CORREGIDO: ya no pasamos userRole a mano; SalesTerminalScreen
            // lo lee directo de currentUserProvider (derivado de
            // authControllerProvider), así que aquí ya no hace falta.
            builder: (context) => const SalesTerminalScreen(),
          ),
        );
      } else if (!wasLoading && next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    });

    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFF232D37),
      body: Center(
        // CORREGIDO: envolvemos todo en un Shortcuts/Actions para que
        // Enter funcione sin importar en qué campo esté el foco.
        child: Shortcuts(
          shortcuts: <LogicalKeySet, Intent>{
            LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
            LogicalKeySet(LogicalKeyboardKey.numpadEnter): const ActivateIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (intent) {
                  _login();
                  return null;
                },
              ),
            },
            child: Focus(
              autofocus: true,
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('OMNINEXUS POS', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF232D37))),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _usernameController,
                      focusNode: _usernameFocus,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Usuario', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                      // CORREGIDO: Enter en 'Usuario' salta directo a 'Contraseña'
                      onSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocus),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
                      // CORREGIDO: Enter en 'Contraseña' entra directo, como pediste
                      onSubmitted: (_) => _login(),
                    ),
                    const SizedBox(height: 20),
                    isLoading
                        ? const CircularProgressIndicator()
                        : SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF232D37)),
                              onPressed: _login,
                              child: const Text('Ingresar', style: TextStyle(color: Colors.white, fontSize: 16)),
                            ),
                          ),
                    const SizedBox(height: 15),
                    const Text(
                      '¿No tienes cuenta? Pídele a tu Administrador que la cree desde Gestión de Personal.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.blueGrey, fontSize: 12),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}