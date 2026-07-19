import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/inventory_screen.dart';
import 'screens/login_screen.dart'; // Verifica que este import coincida con la ruta de tu login

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización actualizada con 'publishableKey' para evitar el aviso de deprecación
  await Supabase.initialize(
    url: 'https://jkxktdmkoolvhsdjrip.supabase.co', // URL de tu proyecto OmniNexus
    publishableKey: 'sb_publishable_Olnu7y7fOCrBhEEzORhV0g_ZAZ-07j8',       // Reemplaza con tu clave Anon actual
  );

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
      home: const AuthWrapper(),
    );
  }
}

/// El AuthWrapper maneja el estado de la sesión y extrae el rol de tu tabla 'users'
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _checkAuthAndRole();
  }

  Future<void> _checkAuthAndRole() async {
    final session = _supabase.auth.currentSession;
    
    if (session != null) {
      try {
        final userId = session.user.id;
        
        // CORREGIDO: Buscando de forma segura en tu tabla exacta de 'users'
        final response = await _supabase
            .from('users') 
            .select('role')   
            .eq('id', userId)
            .single();

        setState(() {
          // Si por alguna razón el usuario no tiene rol asignado, por defecto es Cajero
          _currentUserRole = response['role']?.toString() ?? 'Cajero';
          _isLoading = false;
        });
      } catch (e) {
        // En caso de error de conexión, aplicamos rol seguro restrictivo
        setState(() {
          _currentUserRole = 'Cajero'; 
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mientras consulta la base de datos al iniciar la app
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2C3E50)),
          ),
        ),
      );
    }

    // Si hay una sesión activa y obtuvimos el rol, abrimos el inventario pasando el parámetro
    if (_supabase.auth.currentSession != null && _currentUserRole != null) {
      return InventoryScreen(userRole: _currentUserRole!);
    }

    // Si no está autenticado, directo a la pantalla de Login
    return const LoginScreen(); 
  }
}