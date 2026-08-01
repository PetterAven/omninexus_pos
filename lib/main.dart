import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // 👈 AGREGADO
import 'core/sync_status.dart';
import 'presentation/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // AGREGADO: inicializamos sqflite_ffi ANTES de cualquier acceso a la BD.
  // Debe ejecutarse antes de que AppDatabase.instance.database sea usado
  // por primera vez (login, carga de productos, etc.). Sin esto, en
  // Windows/Linux la app intenta usar el factory nativo de sqflite (que
  // solo existe en Android/iOS) y falla al abrir la base de datos.
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

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

  // NUEVO (Sprint 4, Paso 2): antes se usaba `const ProviderScope(...)`,
  // que crea su ProviderContainer por dentro sin que nadie fuera de la UI
  // pueda tocarlo. Aquí lo creamos a mano para poder pasárselo a
  // SyncStatus.attach() -- así ProductRepository/SalesRepository/
  // AuthRepository (que no son widgets y no tienen `ref`) pueden seguir
  // escribiendo en syncStatusProvider con la misma sintaxis de siempre.
  final container = ProviderContainer();
  SyncStatus.attach(container);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const OmniNexusApp(),
    ),
  );
}

class OmniNexusApp extends StatelessWidget {
  const OmniNexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OmniNexus POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F172A),
          primary: const Color(0xFF0F172A),
          secondary: const Color(0xFF6366F1),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}