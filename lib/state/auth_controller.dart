import 'package:flutter/material.dart';

/// Roles aceptados en la UI:
/// 'Root' | 'Administrador' | 'Usuario'
class AuthController extends ChangeNotifier {
  // --- Datos del usuario autenticado ---
  int? _userId;                 // id real en la BD
  String _role = 'Administrador'; // etiqueta para la UI

  int? get userId => _userId;
  String get role => _role;

  /// Rol en minúsculas para el backend: 'root' | 'admin' | 'usuario'
  String get apiRole {
    if (isRoot) return 'root';
    if (isAdmin) return 'admin';
    return 'usuario';
  }

  /// (Lo que ya usabas)
  void setRole(String role) {
    if (role == _role) return;
    _role = role;
    notifyListeners();
  }

  /// NUEVO: guarda el id del usuario logueado
  /// Llama a esto después del login real.
  void setUserId(int id) {
    if (_userId == id) return;
    _userId = id;
    notifyListeners();
  }

  // --- Políticas de acceso ---
  bool get isRoot => _role == 'Root';
  bool get isAdmin => _role == 'Administrador';
  bool get isUser  => _role == 'Usuario';

  /// Puede ver el módulo "Usuarios" (lista)
  bool get canSeeUsersModule => isRoot || isAdmin;

  /// Puede crear usuarios
  bool get canCreateUsers => isRoot;

  /// Puede administrar usuarios (ELIMINAR, CAMBIAR CONTRASEÑA)
  bool get canManageUsers => isRoot; // <-- SOLO Root

  /// Texto legible
  String get roleLabel => _role;
}

class AuthControllerProvider extends InheritedNotifier<AuthController> {
  const AuthControllerProvider({
    super.key,
    required AuthController controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  static AuthController of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AuthControllerProvider>()!
          .notifier!;

  static AuthController? maybeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AuthControllerProvider>()
          ?.notifier;
}
