import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/constants/env.dart';
import '../models/app_notification.dart';

class NotificationsController extends ChangeNotifier {
  final List<AppNotification> _items = [];

  bool _isLoading = false;
  bool _loadedOnce = false;

  bool get isLoading => _isLoading;
  bool get loadedOnce => _loadedOnce;

  /// Lista ordenada de más nueva a más vieja
  List<AppNotification> get items {
    final copy = [..._items];
    copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return copy;
  }

  int get unreadCount => _items.where((n) => !n.read).length;

  // ================================
  //  Cargar desde backend
  // ================================
  Future<void> loadFromBackend({
    required int userId,
    required String role,
  }) async {
    // Evitar doble carga simultánea
    if (_isLoading) return;

    // Si vienen mal, no pegues al backend (evitas el 401 tonto)
    if (userId <= 0 || role.trim().isEmpty) {
      debugPrint(
          'NotificationsController.loadFromBackend: userId/role inválidos '
              '(userId=$userId, role="$role")');
      return;
    }

    _isLoading = true;
    // 🔴 OJO: NO hacemos notifyListeners aquí para no disparar el error
    // "setState() or markNeedsBuild() called during build".
    // El rebuild se hará cuando termine la petición HTTP.

    try {
      final uri = Uri.parse('${Env.apiBaseUrl}/api/notifications');

      final resp = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': userId.toString(),
          'x-role': role.toLowerCase(), // debe ser root|admin|usuario
        },
      );

      if (resp.statusCode != 200) {
        debugPrint(
          'Error cargando notificaciones: '
              '${resp.statusCode} ${resp.body}',
        );
        // Para que la UI deje de mostrar "primera carga"
        _loadedOnce = true;
        notifyListeners();
        return;
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (data['notifications'] as List<dynamic>? ?? []);

      _items
        ..clear()
        ..addAll(list.map(_fromJsonBackend));

      _loadedOnce = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Excepción en loadFromBackend: $e');
      _loadedOnce = true;
      notifyListeners();
    } finally {
      _isLoading = false;
      // Segundo notify para que la UI se entere que terminó el loading
      notifyListeners();
    }
  }

  /// Convierte un JSON del backend a AppNotification
  AppNotification _fromJsonBackend(dynamic raw) {
    final m = raw as Map<String, dynamic>;

    // id puede venir numérico o string
    final id = m['id']?.toString() ?? '';

    // El backend manda "type" = activity | forum | password_reset
    final typeStr = (m['type'] ??
        m['type_name'] ??
        m['kind'] ??
        'activity')
        .toString()
        .toLowerCase();

    final NotificationKind kind;
    switch (typeStr) {
      case 'passwordreset':
      case 'password_reset':
      case 'restablecer_contraseña':
        kind = NotificationKind.passwordReset;
        break;
      case 'forum':
      case 'foro':
      case 'foro_mensaje':
      case 'foro_nuevo':
        kind = NotificationKind.forum;
        break;
      default:
        kind = NotificationKind.activity;
    }

    // activityEvent opcional (puede venir null o string)
    final eventStr =
    (m['activityEvent'] ?? m['activity_event'])?.toString();
    ActivityEvent? event;
    switch (eventStr) {
      case 'created':
        event = ActivityEvent.created;
        break;
      case 'overdue':
        event = ActivityEvent.overdue;
        break;
      case 'in_progress':
      case 'inProgress':
        event = ActivityEvent.inProgress;
        break;
      case 'done':
        event = ActivityEvent.done;
        break;
      case 'failed':
        event = ActivityEvent.failed;
        break;
      default:
        event = null;
    }

    // Fecha (createdAt o created_at)
    final createdRaw = m['createdAt'] ??
        m['created_at'] ??
        DateTime.now().toIso8601String();
    final createdAt =
        DateTime.tryParse(createdRaw.toString()) ?? DateTime.now();

    // Backend manda is_read como bool o 0/1
    final read = m['read'] == true ||
        m['is_read'] == true ||
        m['is_read'] == 1;

    return AppNotification(
      id: id,
      kind: kind,
      title: (m['title'] ?? '').toString(),
      body: (m['body'] ?? '').toString(),
      createdAt: createdAt,
      activityEvent: event,
      read: read,
    );
  }

  // ================================
  //  Métodos locales (memoria)
  // ================================

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

  void removeLocal(String id) {
    _items.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  void clearAll() {
    _items.clear();
    notifyListeners();
  }

  // ================================
  //  Métodos remotos (API)
  // ================================

  /// Marca una notificación como leída en backend + memoria
  Future<void> markReadRemote({
    required String id,
    required int userId,
    required String role,
  }) async {
    try {
      final uri =
      Uri.parse('${Env.apiBaseUrl}/api/notifications/$id/read');

      final resp = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': userId.toString(),
          'x-role': role.toLowerCase(),
        },
      );

      if (resp.statusCode == 200) {
        markRead(id); // actualiza local
      } else {
        debugPrint(
          'Error markReadRemote: ${resp.statusCode} ${resp.body}',
        );
      }
    } catch (e) {
      debugPrint('Excepción en markReadRemote: $e');
    }
  }

  /// Marca todas como leídas en backend + memoria
  Future<void> markAllReadRemote({
    required int userId,
    required String role,
  }) async {
    try {
      final uri =
      Uri.parse('${Env.apiBaseUrl}/api/notifications/read-all');

      final resp = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': userId.toString(),
          'x-role': role.toLowerCase(),
        },
      );

      if (resp.statusCode == 200) {
        markAllRead(); // actualiza local
      } else {
        debugPrint(
          'Error markAllReadRemote: ${resp.statusCode} ${resp.body}',
        );
      }
    } catch (e) {
      debugPrint('Excepción en markAllReadRemote: $e');
    }
  }

  /// Elimina la notificación para este usuario (DELETE en backend + memoria)
  Future<void> deleteNotificationRemote({
    required String id,
    required int userId,
    required String role,
  }) async {
    try {
      final uri =
      Uri.parse('${Env.apiBaseUrl}/api/notifications/$id');

      final resp = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': userId.toString(),
          'x-role': role.toLowerCase(),
        },
      );

      if (resp.statusCode == 200 || resp.statusCode == 204) {
        removeLocal(id);
      } else {
        debugPrint(
          'Error deleteNotificationRemote: '
              '${resp.statusCode} ${resp.body}',
        );
      }
    } catch (e) {
      debugPrint('Excepción en deleteNotificationRemote: $e');
    }
  }
}

// Provider igual que antes
class NotificationsControllerProvider
    extends InheritedNotifier<NotificationsController> {
  const NotificationsControllerProvider({
    super.key,
    required NotificationsController controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  static NotificationsController of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<
          NotificationsControllerProvider>()!
          .notifier!;

  static NotificationsController? maybeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<
          NotificationsControllerProvider>()
          ?.notifier;
}
