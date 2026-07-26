import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/entities/app_user.dart';

/// Sesión del usuario logueado. A diferencia del checkout (que solo
/// necesitaba loading/error/success sin datos en reposo), aquí sí hay
/// algo que el resto de la app necesita poder leer en cualquier
/// momento: "¿quién está logueado, y con qué rol?". Por eso es
/// AsyncNotifier<AppUser?> en vez de AsyncNotifier<void>.
///
/// - data(null)    -> nadie ha iniciado sesión (mostrar LoginScreen)
/// - data(AppUser) -> sesión activa
/// - loading       -> intentando iniciar sesión ahora mismo
/// - error         -> credenciales incorrectas o falla al validar
///
/// Nota: hoy no hay persistencia de sesión (SharedPreferences/token)
/// -- igual que el comportamiento actual, cada arranque de la app
/// empieza sin sesión. Si más adelante quieres "recordar sesión", este
/// es el lugar natural para cargarla dentro de build().
class AuthController extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() async {
    return null;
  }

  Future<void> login(String username, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await AuthRepository.instance.loginUser(username, password);
      if (user == null) {
        throw Exception('Usuario o contraseña incorrectos');
      }
      return user;
    });
  }

  void logout() {
    state = const AsyncData(null);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AppUser?>(AuthController.new);