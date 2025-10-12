import 'package:flutter/material.dart';
import '../../models/app_notification.dart';
import '../../state/notifications_controller.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  NotificationKind? _kind; // null = todos
  // Filtro por eventos de actividad
  final Set<ActivityEvent> _activityFilter = {
    ActivityEvent.created,
    ActivityEvent.overdue,
    ActivityEvent.inProgress,
    ActivityEvent.done,
    ActivityEvent.failed,
  };

  @override
  Widget build(BuildContext context) {
    final ctrl = NotificationsControllerProvider.of(context);
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        final all = ctrl.items;
        final filtered = all.where((n) {
          if (_kind != null && n.kind != _kind) return false;
          if (n.kind == NotificationKind.activity && n.activityEvent != null) {
            return _activityFilter.contains(n.activityEvent!);
          }
          return true;
        }).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Notificaciones'),
            actions: [
              if (ctrl.unreadCount > 0)
                TextButton(
                  onPressed: ctrl.markAllRead,
                  child: const Text('Marcar todo leído'),
                ),
              const SizedBox(width: 4),
            ],
          ),
          body: Column(
            children: [
              // Segmentos por tipo
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SegmentedButton<NotificationKind?>(
                  segments: const [
                    ButtonSegment(value: null, label: Text('Todas'), icon: Icon(Icons.all_inbox_outlined)),
                    ButtonSegment(value: NotificationKind.activity, label: Text('Actividad'), icon: Icon(Icons.checklist_outlined)),
                    ButtonSegment(value: NotificationKind.passwordReset, label: Text('Contraseña'), icon: Icon(Icons.key_outlined)),
                    ButtonSegment(value: NotificationKind.forum, label: Text('Foros'), icon: Icon(Icons.forum_outlined)),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (s) => setState(() => _kind = s.first),
                ),
              ),

              // Chips de eventos (solo cuando es Actividad)
              if (_kind == NotificationKind.activity)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      _chipEvent(ActivityEvent.created, 'Creada'),
                      _chipEvent(ActivityEvent.overdue, 'Vencida'),
                      _chipEvent(ActivityEvent.inProgress, 'En proceso'),
                      _chipEvent(ActivityEvent.done, 'Terminada'),
                      _chipEvent(ActivityEvent.failed, 'No lograda'),
                    ],
                  ),
                ),

              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No tienes notificaciones con los filtros actuales',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(.7),
                      ),
                    ),
                  ),
                )
                    : ListView.separated(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (_, i) => _NotificationTile(
                    n: filtered[i],
                    onTap: () => ctrl.markRead(filtered[i].id),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chipEvent(ActivityEvent e, String label) {
    final selected = _activityFilter.contains(e);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (v) {
        setState(() {
          if (v) {
            _activityFilter.add(e);
          } else {
            _activityFilter.remove(e);
          }
        });
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification n;
  final VoidCallback onTap;
  const _NotificationTile({required this.n, required this.onTap});

  @override
  Widget build(BuildContext context) {
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

    final color = Theme.of(context).colorScheme;
    final unreadDot = !n.read
        ? Container(width: 8, height: 8, decoration: BoxDecoration(color: color.primary, shape: BoxShape.circle))
        : const SizedBox(width: 8, height: 8);

    return ListTile(
      leading: Badge(
        isLabelVisible: !n.read, // globo: sólo si no leído
        label: const Text(''),
        child: CircleAvatar(
          backgroundColor: color.primaryContainer,
          foregroundColor: color.onPrimaryContainer,
          child: Icon(icon),
        ),
      ),
      title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        n.body,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_timeAgo(n.createdAt),
              style: TextStyle(fontSize: 12, color: color.onSurface.withOpacity(.6))),
          const SizedBox(height: 6),
          unreadDot,
        ],
      ),
      onTap: onTap,
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
