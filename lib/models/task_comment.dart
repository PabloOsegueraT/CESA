class TaskComment {
  final int id;
  final int taskId;
  final int userId;
  final String author;
  final String role;      // 'usuario', 'admin', 'root'
  final String body;
  final DateTime createdAt;
  final bool isAdmin;
  final bool isMine;

  TaskComment({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.author,
    required this.role,
    required this.body,
    required this.createdAt,
    required this.isAdmin,
    required this.isMine,
  });

  factory TaskComment.fromJson(Map<String, dynamic> json) {
    final rawDate = json['createdAt'] ?? json['created_at'];
    DateTime dt = DateTime.now();
    if (rawDate is String && rawDate.isNotEmpty) {
      try {
        dt = DateTime.parse(rawDate);
      } catch (_) {}
    }

    return TaskComment(
      id: (json['id'] as num).toInt(),
      taskId: (json['taskId'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      author: (json['author'] ?? '').toString(),
      role: (json['role'] ?? '').toString().toLowerCase(),
      body: (json['body'] ?? '').toString(),
      createdAt: dt,
      isAdmin: (json['isAdmin'] ?? 0) == 1 || json['isAdmin'] == true,
      isMine: (json['isMine'] ?? 0) == 1 || json['isMine'] == true,
    );
  }
}