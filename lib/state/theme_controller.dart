import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  static const _prefsKey = 'theme_mode';

  // Valor por defecto mientras carga (puedes dejar dark si quieres)
  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get mode => _mode;

  ThemeController() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final int? savedIndex = prefs.getInt(_prefsKey);

    if (savedIndex == null) return; // nunca se ha guardado

    if (savedIndex >= 0 && savedIndex < ThemeMode.values.length) {
      _mode = ThemeMode.values[savedIndex];
      notifyListeners(); // 🔔 avisa al AnimatedBuilder en main
    }
  }

  void set(ThemeMode m) {
    if (m == _mode) return;
    _mode = m;
    notifyListeners();
    _saveToPrefs();
  }

  void toggle(bool isDark) =>
      set(isDark ? ThemeMode.dark : ThemeMode.light);

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, _mode.index);
  }
}

// Proveedor simple con InheritedWidget para acceder desde cualquier pantalla
class ThemeControllerProvider extends InheritedNotifier<ThemeController> {
  const ThemeControllerProvider({
    super.key,
    required ThemeController controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  static ThemeController of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ThemeControllerProvider>()!
          .notifier!;
}