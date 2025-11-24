import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'design_system/theme.dart';
import 'features/auth/login_screen.dart';
import 'features/admin/admin_shell.dart';
import 'features/user/user_shell.dart';
import 'features/settings/settings_screen.dart';
import 'state/theme_controller.dart';
import 'features/settings/profile_screen.dart';
import 'state/profile_controller.dart';
import 'state/users_controller.dart';
import 'features/admin/screens/users_create_screen.dart';
import 'features/admin/screens/users_screen.dart';
import 'state/notifications_controller.dart';
import 'features/notifications/notifications_screen.dart';
import 'state/auth_controller.dart';
import 'features/admin/admin_shell.dart';
import 'features/user/user_shell.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Plugin global para notificaciones locales
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// Handler para mensajes en segundo plano (obligatorio para FCM)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Aquí podrías hacer logs, etc.
}


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Inicializar Firebase
  await Firebase.initializeApp();

  // 2) Registrar handler de mensajes en background
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // 3) Inicializar datos de fechas para español (México)
  await initializeDateFormatting('es_MX', null);

  // 4) Inicializar notificaciones locales (para mostrar cuando la app está abierta)
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  runApp(const TaskManagerApp());
}

class TaskManagerApp extends StatefulWidget {
  const TaskManagerApp({super.key}); // a.k.a MyApp para tests

  @override
  State<TaskManagerApp> createState() => _TaskManagerAppState();
}

class _TaskManagerAppState extends State<TaskManagerApp> {
  final ThemeController _theme = ThemeController();
  final ProfileController _profile = ProfileController();
  final UsersController _users = UsersController();
  final NotificationsController _notifications = NotificationsController();
  final AuthController _auth = AuthController();

  @override
  void initState() {
    super.initState();

    // Escuchar notificaciones cuando la app está en primer plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;

      const androidDetails = AndroidNotificationDetails(
        'default_channel', // id del canal
        'Notificaciones',  // nombre del canal
        importance: Importance.max,
        priority: Priority.high,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        notificationDetails,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ThemeControllerProvider(
      controller: _theme,
      child: ProfileControllerProvider(
        controller: _profile,
        child: UsersControllerProvider(
          controller: _users,
          child: NotificationsControllerProvider(
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
                      '/admin': (_) => AdminShell(),
                      '/user': (_) => UserShell(),

                      '/settings': (_) => const SettingsScreen(),
                      '/profile': (_) => const ProfileScreen(),
                      '/create-user': (_) => const AdminUserCreateScreen(),
                      '/admin-users': (_) => const AdminUsersScreen(),
                      '/notifications': (_) =>
                      const NotificationsScreen(),
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
