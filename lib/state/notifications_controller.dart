import 'package:flutter/material.dart';
import '../models/app_notification.dart';

class NotificationsController extends ChangeNotifier {
  final List<AppNotification> _items = [
    AppNotification(
      id: 'n1',
      kind: NotificationKind.activity,
      title: 'Tarea creada',
      body: '“Landing sprint” fue creada y asignada a ti.',
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      activityEvent: ActivityEvent.created,
    ),
    AppNotification(
      id: 'n2',
      kind: NotificationKind.activity,
      title: 'Tarea vencida',
      body: '“Reporte Q4” venció hoy.',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      activityEvent: ActivityEvent.overdue,
    ),
    AppNotification(
      id: 'n3',
      kind: NotificationKind.passwordReset,
      title: 'Solicitud de restablecimiento',
      body: 'El root recibió tu solicitud de contraseña.',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    AppNotification(
      id: 'n4',
      kind: NotificationKind.forum,
      title: 'Nuevo mensaje en foro',
      body: 'Marco respondió en “Release 1.2”.',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  List<AppNotification> get items =>
      _items..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  int get unreadCount => _items.where((n) => !n.read).length;

  void add(AppNotification n) {
    _items.insert(0, n);
    notifyListeners();
  }

  void markRead(String id) {
    final i = _items.indexWhere((n) => n.id == id);
    if (i == -1) return;
    _items[i] = _items[i].copyWith(read: true);
    notifyListeners();
  }

  void markAllRead() {
    for (var i = 0; i < _items.length; i++) {
      _items[i] = _items[i].copyWith(read: true);
    }
    notifyListeners();
  }

  void clearAll() {
    _items.clear();
    notifyListeners();
  }
}

class NotificationsControllerProvider
    extends InheritedNotifier<NotificationsController> {
  const NotificationsControllerProvider({
    super.key,
    required NotificationsController controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  static NotificationsController of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<NotificationsControllerProvider>()!
          .notifier!;

  static NotificationsController? maybeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<NotificationsControllerProvider>()
          ?.notifier;
}
