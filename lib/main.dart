import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'presentation/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // CORREGIDO: las credenciales ya NO están escritas en el código. Se leen
  // del archivo .env (que está en .gitignore y nunca se sube a GitHub).
  // Si falta el .env o alguna variable, tiramos un error claro en vez de
  // que la app truene con un mensaje confuso más adelante.
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('⚠️ No se encontró el archivo .env. Copia .env.example como .env y pon tus credenciales.');
  }

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseAnonKey == null) {
    debugPrint('⚠️ Faltan SUPABASE_URL o SUPABASE_ANON_KEY en el .env. La app arrancará en modo local únicamente.');
  } else {
    // CORREGIDO: protegemos la inicialización con timeout + try/catch.
    // Si la red está lenta/rota (como ya nos pasó), esto evita que la app
    // se quede trabada antes de mostrar cualquier pantalla. Si falla, la app
    // arranca igual y trabaja en modo local hasta que haya conexión.
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('⚠️ No se pudo conectar con Supabase al iniciar (modo offline): $e');
    }
  }

  runApp(const OmniNexusApp());
}

class OmniNexusApp extends StatelessWidget {
  const OmniNexusApp({super.key});

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