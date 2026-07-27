import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/entities/app_user.dart';

/// Resultado de intentar registrar un empleado. Igual que
/// CartOperationResult/ProductSaveResult: el controller no conoce
/// BuildContext, así que regresa un resultado y la UI decide el
/// SnackBar/mensaje exacto (incluida la razón de rechazo que hoy viene
/// como texto libre de AuthRepository.registerUser).
enum UserSaveResult {
  success,
  notAuthorized,
}

/// Estado de las cuentas de personal (cajero/administrador).
///
/// Extraído de sales_report_dialog.dart: antes `sales`/`users` vivían
/// como variables locales del StatefulBuilder del diálogo, refrescadas
/// a mano con setDialogState() después de cada create/delete. Aquí,
/// igual que ProductController, es AsyncNotifier<List<AppUser>> para
/// que loading/error salgan gratis de AsyncValue.
class UserController extends AsyncNotifier<List<AppUser>> {
  @override
  Future<List<AppUser>> build() async {
    return AuthRepository.instance.getUsers();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => AuthRepository.instance.getUsers());
  }

  /// currentOperatorRole se sigue pasando explícito (no se lee de
  /// currentUserProvider aquí adentro) porque el controller no debe
  /// depender de otro provider de sesión para una validación de
  /// autorización que ya hace AuthRepository -- mantiene al controller
  /// testeable de forma aislada, igual que ya hacía registerUser().
  Future<UserSaveResult> addUser({
    required String currentOperatorRole,
    required String username,
    required String password,
    required String role,
  }) async {
    if (currentOperatorRole != 'Administrador') {
      return UserSaveResult.notAuthorized;
    }

    await AuthRepository.instance.registerUser(
      currentOperatorRole: currentOperatorRole,
      newUsername: username,
      newPassword: password,
      newRole: role,
    );
    await refresh();
    return UserSaveResult.success;
  }

  Future<void> deleteUser(String username) async {
    await AuthRepository.instance.deleteUser(username);
    await refresh();
  }
}

final userControllerProvider =
    AsyncNotifierProvider<UserController, List<AppUser>>(UserController.new);