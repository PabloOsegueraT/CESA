import 'package:flutter/material.dart';
import 'design_system/theme.dart';
import 'features/auth/login_screen.dart';
import 'features/admin/admin_shell.dart';
import 'features/user/user_shell.dart';
import 'features/settings/settings_screen.dart';
import 'state/theme_controller.dart';
import 'features/settings/profile_screen.dart';
import 'state/profile_controller.dart';
import 'state/users_controller.dart';
import 'features/admin/screens/create_user_screen.dart';
import 'features/admin/screens/users_screen.dart';
import 'state/notifications_controller.dart';
import 'features/notifications/notifications_screen.dart';
import 'state/auth_controller.dart';

void main() {
  runApp(const TaskManagerApp());
}

class TaskManagerApp extends StatefulWidget {
  const TaskManagerApp({super.key}); // a.k.a MyApp para tests
  @override
  State<TaskManagerApp> createState() => _TaskManagerAppState();
}

class _TaskManagerAppState extends State<TaskManagerApp> {
  final ThemeController _theme = ThemeController();
  final ProfileController _profile = ProfileController(); // <-- NUEVO
  final UsersController _users = UsersController(); // NUEVO
  final NotificationsController _notifications = NotificationsController();
  final AuthController _auth = AuthController();


  @override
  Widget build(BuildContext context) {
    return ThemeControllerProvider(
      controller: _theme,
      child: ProfileControllerProvider( // <- ENVUELVE A MaterialApp
        controller: _profile,
        child: UsersControllerProvider(                       // <-- ENVUELVE AQUÍ
          controller: _users,
          child: NotificationsControllerProvider(          // ← NUEVO
            controller: _notifications,
            child: AuthControllerProvider(
              controller: _auth,
        child: AnimatedBuilder(
          animation: _theme,
          builder: (context, _) {
            return MaterialApp(
              title: 'Task Manager',
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: _theme.mode,
              debugShowCheckedModeBanner: false,
              initialRoute: '/auth',
              routes: {
                '/auth': (_) => const LoginScreen(),
                '/admin': (_) => const AdminShell(),
                '/user': (_) => const UserShell(),
                '/settings': (_) => const SettingsScreen(),
                '/profile': (_) => const ProfileScreen(),
                '/create-user': (_) => const CreateUserScreen(),
                '/admin-users': (_) => const AdminUsersScreen(),
                '/notifications': (_) => const NotificationsScreen(),
              },
            );
          },
        ),
      ),
    )
    )
    )
    );
  }
}

