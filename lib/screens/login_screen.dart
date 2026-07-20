import 'package:flutter/material.dart';
import '../models/database_helper.dart';
import 'sales_terminal_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _login() async {
    final user = _usernameController.text.trim();
    final pass = _passwordController.text;

    if (user.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor llena todos los campos'))
      );
      return;
    }

    setState(() => _isLoading = true);
    final userData = await DatabaseHelper.instance.loginUser(user, pass);
    setState(() => _isLoading = false);

    if (userData != null) {
      _usernameController.clear();
      _passwordController.clear();
      if (!mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SalesTerminalScreen(userRole: userData['role']),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario o contraseña incorrectos'))
      );
    }
  }

  // 🛡️ El auto-registro público fue retirado por seguridad (Regla tipo Walmart):
  // ningún usuario anónimo puede crear cuentas, y mucho menos elegir su propio rol.
  // Las cuentas ahora solo se crean desde "Gestión de Personal", dentro del sistema,
  // por un usuario que ya inició sesión con rol Administrador.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF232D37),
      body: Center(
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
                decoration: const InputDecoration(labelText: 'Usuario', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
              ),
              const SizedBox(height: 20),
              _isLoading
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
    );
  }
}