import 'dart:typed_data';

class AppUser {
  final String id;
  final String name;
  final String email;
  final String role; // 'Administrador' | 'Usuario'
  final String? phone;
  final String password;       // DEMO: plano (no usar en prod)
  final Uint8List? avatarBytes; // foto (opcional, en memoria)

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.password,
    this.phone,
    this.avatarBytes,
  });

  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? phone,
    String? password,
    Uint8List? avatarBytes,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      password: password ?? this.password,
      phone: phone ?? this.phone,
      avatarBytes: avatarBytes ?? this.avatarBytes,
    );
  }
}
