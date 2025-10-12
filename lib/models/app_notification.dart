enum NotificationKind { activity, passwordReset, forum }

/// Eventos de gestión de actividad (tareas)
enum ActivityEvent { created, overdue, inProgress, done, failed }

class AppNotification {
  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;

  // Metadatos opcionales según el tipo
  final ActivityEvent? activityEvent;
  final String? relatedId; // id de tarea, foro, etc.

  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
    this.activityEvent,
    this.relatedId,
  });

  AppNotification copyWith({
    String? id,
    NotificationKind? kind,
    String? title,
    String? body,
    DateTime? createdAt,
    bool? read,
    ActivityEvent? activityEvent,
    String? relatedId,
  }) {
    return AppNotification(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      read: read ?? this.read,
      activityEvent: activityEvent ?? this.activityEvent,
      relatedId: relatedId ?? this.relatedId,
    );
  }
}
