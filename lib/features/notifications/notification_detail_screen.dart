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

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de notificación'),
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
