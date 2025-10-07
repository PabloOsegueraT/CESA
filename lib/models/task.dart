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
}
