import 'package:flutter/material.dart';

class ProfileController extends ChangeNotifier {
  int? _userId;
  String _displayName = 'Pablo Admin';
  String _email = 'admin@demo.com';
  String _role = 'Administrador';
  String _phone = '+52 55 1234 5678';
  String _about = 'Apasionado de la gestión y los sprints bien cerrados.';

  int? get userId => _userId;
  String get displayName => _displayName;
  String get email => _email;
  String get role => _role;
  String get phone => _phone;
  String get about => _about;

  // 🔹 Getters alias para que el resto del código compile
  String get name => _displayName;     // <- para usar profile.name
  String get roleLabel => _role;       // <- por si en algún lado usas roleLabel

  /// Usado desde el login: normaliza y establece el perfil inicial.
  /// Nota: `roleLabel` llega como 'Root' | 'Administrador' | 'Usuario'
  void setProfile({
    required String name,
    required String email,
    required String roleLabel,
    int? userId,
    String? phone,
    String? about,
  }) {
    _userId = userId;
    _displayName = name;
    _email = email;
    _role = roleLabel;
    if (phone != null) _phone = phone;
    if (about != null) _about = about;
    notifyListeners();
  }
  /// Actualización parcial desde pantallas de edición de perfil.
  void update({
    String? displayName,
    String? email,
    String? role,
    String? phone,
    String? about,
  }) {
    if (displayName != null) _displayName = displayName;
    if (email != null) _email = email;
    if (role != null) _role = role;
    if (phone != null) _phone = phone;
    if (about != null) _about = about;
    notifyListeners();
  }
}

// Proveedor tipo InheritedNotifier
class ProfileControllerProvider extends InheritedNotifier<ProfileController> {
  const ProfileControllerProvider({
    super.key,
    required ProfileController controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  static ProfileController of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ProfileControllerProvider>()!
          .notifier!;

  /// Versión segura: retorna null si no está envuelto en el árbol.
  static ProfileController? maybeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ProfileControllerProvider>()
          ?.notifier;
}