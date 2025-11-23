import 'package:flutter/material.dart';

import '../../models/app_notification.dart';
import '../../state/notifications_controller.dart';
import '../../state/profile_controller.dart';

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
  bool _markedReadOnce = false;
  bool _deleting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Marcar como leída solo la primera vez que entramos
    if (_markedReadOnce) return;
    _markedReadOnce = true;

    final profile = ProfileControllerProvider.maybeOf(context);
    final userId = profile?.userId ?? 0;
    final role = (profile?.roleLabel ?? '').toLowerCase();
    final ctrl = NotificationsControllerProvider.of(context);

    if (userId > 0) {
      // 🔹 Marca en backend + actualiza en memoria
      ctrl.markReadRemote(
        id: widget.notification.id,
        userId: userId,
        role: role,
      );
    } else {
      // Por si algo raro pasa con el perfil, al menos marcar local
      ctrl.markRead(widget.notification.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final n = widget.notification;

    final icon = switch (n.kind) {
      NotificationKind.activity => switch (n.activityEvent) {
        ActivityEvent.created    => Icons.add_task,
        ActivityEvent.overdue    => Icons.warning_amber_outlined,
        ActivityEvent.inProgress => Icons.play_circle_outline,
        ActivityEvent.done       => Icons.task_alt,
        ActivityEvent.failed     => Icons.block_outlined,
        _                        => Icons.checklist_outlined,
      },
      NotificationKind.passwordReset => Icons.key_outlined,
      NotificationKind.forum         => Icons.forum_outlined,
    };

    final kindLabel = switch (n.kind) {
      NotificationKind.activity      => 'Actividad',
      NotificationKind.passwordReset => 'Contraseña',
      NotificationKind.forum         => 'Foro',
    };

    final createdStr = _formatDateTime(n.createdAt);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de notificación'),
        actions: [
          IconButton(
            tooltip: 'Eliminar notificación',
            onPressed: _deleting ? null : () => _confirmDelete(context),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado con icono + tipo + fecha
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: colors.primaryContainer,
                      foregroundColor: colors.onPrimaryContainer,
                      child: Icon(icon),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      kindLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      createdStr,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurface.withOpacity(.6),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                Text(
                  n.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),

                // Cuerpo de la notificación
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      n.body,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar notificación'),
        content: const Text(
          '¿Seguro que quieres eliminar esta notificación?\n'
              'Solo se quitará de tu bandeja, no afecta a otros usuarios.',
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

    if (ok != true) return;

    setState(() => _deleting = true);

    final profile = ProfileControllerProvider.maybeOf(context);
    final userId = profile?.userId ?? 0;
    final role = (profile?.roleLabel ?? '').toLowerCase();

    if (userId <= 0) {
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo identificar al usuario actual'),
        ),
      );
      return;
    }

    final ctrl = NotificationsControllerProvider.of(context);

    await ctrl.deleteNotificationRemote(
      id: widget.notification.id,
      userId: userId,
      role: role,
    );

    if (!mounted) return;

    setState(() => _deleting = false);
    Navigator.of(context).pop(); // Cierra el detalle y vuelve a la lista
  }

  String _formatDateTime(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);

    if (diff.inMinutes < 1) return 'Hace un momento';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    return '${d.year}-${_two(d.month)}-${_two(d.day)} '
        '${_two(d.hour)}:${_two(d.minute)}';
  }

  String _two(int n) => n.toString().padLeft(2, '0');
}