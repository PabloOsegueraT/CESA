import 'package:flutter/material.dart';
import '../models/user.dart';

class UsersController extends ChangeNotifier {
  final List<AppUser> _users = [
    const AppUser(id: 'u1', name: 'Pablo',   email: 'pablo@demo.com',   role: 'Administrador', password: 'demo123'),
    const AppUser(id: 'u2', name: 'Marco',   email: 'marco@demo.com',   role: 'Usuario',       password: 'demo123'),
    const AppUser(id: 'u3', name: 'Andoni',  email: 'andoni@demo.com',  role: 'Usuario',       password: 'demo123'),
    const AppUser(id: 'u4', name: 'Joaquín', email: 'joaquin@demo.com', role: 'Usuario',       password: 'demo123'),
    const AppUser(id: 'u0', name: 'Admin',   email: 'admin@demo.com',   role: 'Administrador', password: 'admin'),
  ];


  List<AppUser> get users => List.unmodifiable(_users);

  void addUser(AppUser u) {
    _users.insert(0, u);
    notifyListeners();
  }

  void removeUser(String id) {
    _users.removeWhere((u) => u.id == id);
    notifyListeners();
  }

  void updatePassword(String id, String newPassword) {
    final idx = _users.indexWhere((u) => u.id == id);
    if (idx == -1) return;
    _users[idx] = _users[idx].copyWith(password: newPassword);
    notifyListeners();
  }

}

class UsersControllerProvider extends InheritedNotifier<UsersController> {
  const UsersControllerProvider({
    super.key,
    required UsersController controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  static UsersController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UsersControllerProvider>()!.notifier!;
}
