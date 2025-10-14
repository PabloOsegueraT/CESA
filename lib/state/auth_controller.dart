import 'package:flutter/material.dart';

/// Roles aceptados:
/// 'Root' | 'Administrador' | 'Usuario'
class AuthController extends ChangeNotifier {
  String _role = 'Administrador'; // cambia a 'Root' o 'Usuario' según login real
  String get role => _role;

  void setRole(String role) {
    if (role == _role) return;
    _role = role;
    notifyListeners();
  }

  // --- Políticas de acceso ---
  bool get isRoot => _role == 'Root';
  bool get isAdmin => _role == 'Administrador';
  bool get isUser  => _role == 'Usuario';

  /// Puede ver el módulo "Usuarios" (lista, crear)
  bool get canSeeUsersModule => isRoot || isAdmin;

  /// Puede crear usuarios (per tu requerimiento: Admin SÍ puede crear)
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
      context.dependOnInheritedWidgetOfExactType<AuthControllerProvider>()!.notifier!;
  static AuthController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthControllerProvider>()?.notifier;
}
