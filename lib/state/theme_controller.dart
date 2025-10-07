import 'package:flutter/material.dart';

class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.dark; // por defecto oscuro
  ThemeMode get mode => _mode;

  void set(ThemeMode m) {
    if (m == _mode) return;
    _mode = m;
    notifyListeners();
  }

  void toggle(bool isDark) => set(isDark ? ThemeMode.dark : ThemeMode.light);
}

// Proveedor simple con InheritedWidget para acceder desde cualquier pantalla
class ThemeControllerProvider extends InheritedNotifier<ThemeController> {
  const ThemeControllerProvider({
    super.key,
    required ThemeController controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  static ThemeController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeControllerProvider>()!.notifier!;
}

