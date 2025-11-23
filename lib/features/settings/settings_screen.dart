import 'package:flutter/material.dart';
import '../../state/theme_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Controlador global del tema
    final themeCtrl = ThemeControllerProvider.of(context);
    final isDark = themeCtrl.mode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
      ),
      body: ListView(
        children: [
          SwitchListTile.adaptive(
            title: const Text('Tema oscuro'),
            subtitle: Text(isDark ? 'Activado' : 'Desactivado'),
            value: isDark,
            onChanged: (v) {
              // Cambia el tema y además lo guarda en SharedPreferences
              themeCtrl.toggle(v);
            },
            secondary: Icon(
              isDark ? Icons.dark_mode : Icons.light_mode_outlined,
            ),
          ),
        ],
      ),
    );
  }
}