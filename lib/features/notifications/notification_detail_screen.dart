import 'package:flutter/material.dart';

import '../../models/app_notification.dart';
import '../../state/profile_controller.dart';
import '../../state/notifications_controller.dart';

class NotificationDetailScreen extends StatefulWidget {
  final AppNotification notification;

  const NotificationDetailScreen({
    super.key,
    required this.notification,
  });

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  bool _alreadyMarked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureMarkedReadOnce();
  }

  void _ensureMarkedReadOnce() {
    if (_alreadyMarked) return;

    final profile  = ProfileControllerProvider.maybeOf(context);
    final notifCtrl = NotificationsControllerProvider.maybeOf(context);

    if (profile == null || notifCtrl == null) return;

    final int? userId = profile.userId;
    if (userId == null || userId <= 0) return;   // ✅ null-safe

    final role = _mapRoleToBackend(profile.roleLabel ?? '');

    // Marcamos como leída DESPUÉS del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifCtrl.markReadRemote(
        id: widget.notification.id,
        userId: userId,   // ✅ ya no es null porque pasó el if de arriba
        role: role,
      );
    });

    _alreadyMarked = true;
  }

  /// Mapea el label que usa Flutter a lo que espera el backend
  String _mapRoleToBackend(String raw) {
    final v = raw.trim().toLowerCase();

    if (v.contains('root')) return 'root';
    if (v.contains('admin')) return 'admin';
    // alumno, estudiante, usuario, etc → 'usuario'
    return 'usuario';
  }

  // 🔥 Confirmación antes de borrar
  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar notificación'),
        content: const Text(
          '¿Seguro que quieres eliminar esta notificación? '
              'Solo se eliminará para tu usuario.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _deleteNotification();
    }
  }

  // 🔥 Llama al controller y al backend para borrar
  Future<void> _deleteNotification() async {
    final profile  = ProfileControllerProvider.maybeOf(context);
    final notifCtrl = NotificationsControllerProvider.maybeOf(context);

    if (profile == null || notifCtrl == null) return;

    final int? userId = profile.userId;
    if (userId == null || userId <= 0) return;

    final role = _mapRoleToBackend(profile.roleLabel ?? '');

    // DELETE en backend + removeLocal() en el controller
    await notifCtrl.deleteNotificationRemote(
      id: widget.notification.id,
      userId: userId,
      role: role,
    );

    if (!mounted) return;

    Navigator.of(context).pop(); // volvemos a la lista
    // Si quieres, puedes mostrar un SnackBar en la pantalla anterior
    // usando un result: Navigator.pop(context, true); y manejarlo allá.
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de notificación'),
        actions: [
          IconButton(
            tooltip: 'Eliminar notificación',
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              n.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _timeAgo(n.createdAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text(
              n.body,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    return '${diff.inDays} d';
  }
}