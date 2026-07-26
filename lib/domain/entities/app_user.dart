
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
