// lib/models/task.dart

enum TaskPriority { low, medium, high }
enum TaskStatus { pending, inProgress, done }

class Task {
  final String id;
  final String title;
  final String description;
  final DateTime dueDate;
  final TaskPriority priority;
  final TaskStatus status;
  final String assignee; // nombre visible del asignado
  final int evidenceCount;
  final int commentsCount;

  const Task({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.priority,
    required this.status,
    required this.assignee,
    this.evidenceCount = 0,
    this.commentsCount = 0,
  });

  Task copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dueDate,
    TaskPriority? priority,
    TaskStatus? status,
    String? assignee,
    int? evidenceCount,
    int? commentsCount,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      assignee: assignee ?? this.assignee,
      evidenceCount: evidenceCount ?? this.evidenceCount,
      commentsCount: commentsCount ?? this.commentsCount,
    );
  }

  // ====== Helpers para mapear con la API ======

  static TaskPriority _priorityFromApi(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'low':
        return TaskPriority.low;
      case 'high':
        return TaskPriority.high;
      case 'medium':
      default:
        return TaskPriority.medium;
    }
  }

  static String priorityToApi(TaskPriority p) {
    switch (p) {
      case TaskPriority.low:
        return 'low';
      case TaskPriority.medium:
        return 'medium';
      case TaskPriority.high:
        return 'high';
    }
  }

  static TaskStatus _statusFromApi(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'in_progress':
        return TaskStatus.inProgress;
      case 'done':
        return TaskStatus.done;
      case 'pending':
      default:
        return TaskStatus.pending;
    }
  }

  static String statusToApi(TaskStatus s) {
    switch (s) {
      case TaskStatus.pending:
        return 'pending';
      case TaskStatus.inProgress:
        return 'in_progress';
      case TaskStatus.done:
        return 'done';
    }
  }

  // ====== JSON <-> Modelo ======

  factory Task.fromJson(Map<String, dynamic> json) {
    final due = json['dueDate'];
    final dueDate = (due == null || due.toString().isEmpty)
        ? DateTime.now()
        : DateTime.parse(due as String); // 'YYYY-MM-DD' OK

    return Task(
      id: json['id'].toString(),
      title: (json['title'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      dueDate: dueDate,
      priority: _priorityFromApi(json['priority'] as String?),
      status: _statusFromApi(json['status'] as String?),
      assignee: (json['assignee'] ?? 'Sin asignar') as String,
      // Estos dos dependen de lo que devuelva el backend.
      // Si aún no los mandas, se quedan en 0.
      evidenceCount: (json['evidenceCount'] ?? 0) as int,
      commentsCount: (json['commentsCount'] ?? 0) as int,
    );
  }

  /// Útil si quieres construir el body para POST /api/tasks
  Map<String, dynamic> toJsonForCreate() {
    return {
      'title': title,
      'description': description,
      'priority': priorityToApi(priority),        // low|medium|high
      'dueDate': dueDate.toIso8601String().substring(0, 10), // YYYY-MM-DD
      // el assigneeId lo manejas afuera porque aquí solo tienes el nombre
    };
  }
}
