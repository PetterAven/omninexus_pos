/// Entidad de dominio: un usuario del sistema (cajero, administrador,
/// etc). El campo `password` siempre contiene el hash bcrypt, nunca
/// texto plano.
class AppUser {
  final String username;
  final String password;
  final String role;

  const AppUser({
    required this.username,
    required this.password,
    required this.role,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        username: map['username'].toString(),
        password: map['password'].toString(),
        role: map['role'].toString(),
      );
}
