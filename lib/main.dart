import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // CORREGIDO: protegemos la inicialización con timeout + try/catch.
  // Si la red está lenta/rota (como ya nos pasó), esto evita que la app
  // se quede trabada antes de mostrar cualquier pantalla. Si falla, la app
  // arranca igual y trabaja en modo local hasta que haya conexión.
  try {
    await Supabase.initialize(
      url: 'https://jkxktdmkoolvhsvdjrip.supabase.co',
      publishableKey: 'sb_publishable_Olnu7y7fOCrBhEEzORhV0g_ZAZ-07j8',
    ).timeout(const Duration(seconds: 8));
  } catch (e) {
    debugPrint('⚠️ No se pudo conectar con Supabase al iniciar (modo offline): $e');
  }

  runApp(const OmniNexusApp());
}

class OmniNexusApp extends StatelessWidget {
  const OmniNexusApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OmniNexus POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF2C3E50),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2C3E50)),
        useMaterial3: true,
      ),
      // CORREGIDO: se elimina el AuthWrapper. Tu login real es manual
      // contra la tabla 'users' (DatabaseHelper.loginUser), no usa
      // Supabase Auth (_supabase.auth), así que ese wrapper nunca hacía
      // nada útil — solo agregaba una consulta a una columna 'id' que tu
      // tabla 'users' ni siquiera tiene. Vamos directo al login real.
      home: const LoginScreen(),
    );
  }
}